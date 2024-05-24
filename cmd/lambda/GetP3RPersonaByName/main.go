package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	GetPersonaCompendiumErrors "github.com/bradleyGamiMarques/PersonaCompendiumErrors"
	GetPersonaServiceTypes "github.com/bradleyGamiMarques/get-persona-service-types"
)

// Create global variables to extract initialization logic out of the handler.
var svc *dynamodb.Client
var tableName string
var initOnce sync.Once
var initError error

// initAWS returns an error or nil representing the state of the initialization
// of the AWS SDK configuration and DynamoDB client.
func initAWS(ctx context.Context) error {
	var err error

	tableName = os.Getenv("DYNAMODB_TABLE_NAME")
	if tableName == "" {
		log.Println("Internal Server Error: DYNAMODB_TABLE_NAME environment variable not set")
		return fmt.Errorf("DYNAMODB_TABLE_NAME environment variable not set")
	}

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Printf("Internal Server Error: failed to load configuration: %v\n", err)
		return fmt.Errorf("failed to load configuration: %v", err)
	}

	svc = dynamodb.NewFromConfig(cfg)
	return nil
}

// sanitizeInput validates and sanitizes the input to prevent security issues
func sanitizeInput(input string) (string, error) {
	// Trim leading and trailing spaces
	trimmedInput := strings.TrimSpace(input)
	// Disallowing special characters except for hyphens, letters, and spaces
	re := regexp.MustCompile(`^[-a-zA-Z ]+$`)
	if !re.MatchString(trimmedInput) {
		return "", fmt.Errorf("invalid input: %s", input)
	}
	return trimmedInput, nil
}

func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	initOnce.Do(func() {
		initError = initAWS(ctx)
	})
	if initError != nil {
		log.Printf("Internal Server Error: %v", initError)
		errorResponse := GetPersonaCompendiumErrors.InternalServerError("Something went wrong", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	// Extract the persona name from the path parameters
	personaName := request.PathParameters["personaName"]
	decodedPersonaName, err := url.PathUnescape(personaName)

	if err != nil {
		log.Printf("Bad Request: failed to decode persona name: %v\n", err)
		errorResponse := GetPersonaCompendiumErrors.BadRequestError("Invalid persona name", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	// Trim and sanitize the input
	sanitizedPersonaName, err := sanitizeInput(decodedPersonaName)
	if err != nil {
		log.Printf("Bad Request: %v", err)
		errorResponse := GetPersonaCompendiumErrors.BadRequestError("Invalid persona name", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	if sanitizedPersonaName == "" {
		log.Println("Bad Request: Path parameter personaName is required")
		errorResponse := GetPersonaCompendiumErrors.BadRequestError("Path parameter personaName is required", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	// Prepare the input for the query
	input := &dynamodb.QueryInput{
		TableName:              aws.String(tableName),
		IndexName:              aws.String("PersonaIndex"),
		KeyConditionExpression: aws.String("PersonaName = :personaName"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":personaName": &types.AttributeValueMemberS{Value: sanitizedPersonaName},
		},
	}

	// Retrieve the item from DynamoDB
	result, err := svc.Query(ctx, input)
	if err != nil {
		log.Printf("Internal Server Error: failed to query item: %v", err)
		errorResponse := GetPersonaCompendiumErrors.InternalServerError("Something went wrong", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	if len(result.Items) == 0 {
		log.Printf("Not Found: there is no Persona with that name: %s", sanitizedPersonaName)
		errorResponse := GetPersonaCompendiumErrors.NotFoundError("There is no Persona with that name", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	var response GetPersonaServiceTypes.GetP3RPersonaByNameResponse
	err = attributevalue.UnmarshalMap(result.Items[0], &response)
	if err != nil {
		log.Printf("Error: failed to unmarshal response: %v", err)
		errorResponse := GetPersonaCompendiumErrors.InternalServerError("Something went wrong", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	responseBody, err := json.Marshal(response)
	if err != nil {
		log.Printf("Error: failed to marshal response: %v", err)
		errorResponse := GetPersonaCompendiumErrors.InternalServerError("Something went wrong", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	return events.APIGatewayProxyResponse{
		StatusCode:        200,
		MultiValueHeaders: nil,
		Headers:           map[string]string{"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
		Body:              string(responseBody),
		IsBase64Encoded:   false,
	}, nil
}

func main() {
	lambda.Start(HandleRequest)
}
