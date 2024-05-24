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
var arcanas = [22]string{"Aeon", "Chariot", "Death", "Devil", "Emperess", "Emperor", "Fool", "Fortune", "Hanged Man", "Hermit", "Hierophant", "Judgement", "Justice", "Lovers", "Magician", "Moon", "Priestess", "Star", "Strength", "Sun", "Temperance", "Tower"}

func binarySearch(arr []string, target string) int {
	left, right := 0, len(arr)-1

	for left <= right {
		mid := left + (right-left)/2

		if arr[mid] == target {
			return mid
		} else if arr[mid] < target {
			left = mid + 1
		} else {
			right = mid - 1
		}
	}
	return -1
}

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
	// Disallowing special characters except for letters, and spaces
	re := regexp.MustCompile(`^[a-zA-Z ]+$`)
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

	// Extract the persona arcana from the path parameters
	arcana := request.PathParameters["arcana"]
	decodedArcana, err := url.PathUnescape(arcana)

	if err != nil {
		log.Printf("Bad Request: failed to decode persona arcana: %v\n", err)
		errorResponse := GetPersonaCompendiumErrors.BadRequestError("Invalid arcana", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	// Trim and sanitize the input
	sanitizedArcana, err := sanitizeInput(decodedArcana)
	if err != nil {
		log.Printf("Bad Request: %v", err)
		errorResponse := GetPersonaCompendiumErrors.BadRequestError("Invalid arcana", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	if sanitizedArcana == "" {
		log.Println("Bad Request: Path parameter arcana is required")
		errorResponse := GetPersonaCompendiumErrors.BadRequestError("Path parameter arcana is required", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	if binarySearch(arcanas[:], sanitizedArcana) == -1 {
		log.Println("Not Found: Arcana not found")
		errorResponse := GetPersonaCompendiumErrors.NotFoundError("Arcana not found", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	// Prepare the input for the query
	input := &dynamodb.QueryInput{
		TableName:              aws.String(tableName),
		KeyConditionExpression: aws.String("Arcana = :hk"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":hk": &types.AttributeValueMemberS{Value: sanitizedArcana},
		},
	}

	// Retrieve the items from DynamoDB
	result, err := svc.Query(ctx, input)
	if err != nil {
		log.Printf("Internal Server Error: failed to query items: %v", err)
		errorResponse := GetPersonaCompendiumErrors.InternalServerError("Something went wrong", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	if len(result.Items) == 0 {
		log.Printf("Not Found: there are no Personas in that arcana: %s", sanitizedArcana)
		errorResponse := GetPersonaCompendiumErrors.NotFoundError("There are no personas in that arcana", request.Path)
		return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
	}

	var response GetPersonaServiceTypes.GetP3RPersonasByArcanaResponse
	for _, persona := range result.Items {
		var item GetPersonaServiceTypes.GetP3RPersonaByNameResponse
		err = attributevalue.UnmarshalMap(persona, &item)
		if err != nil {
			log.Printf("Error: failed to unmarshal response: %v", err)
			errorResponse := GetPersonaCompendiumErrors.InternalServerError("Something went wrong", request.Path)
			return GetPersonaCompendiumErrors.JSONResponse(errorResponse)
		}
		response = append(response, item)
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
