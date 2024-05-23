package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	GetPersonaServiceTypes "github.com/bradleyGamiMarques/GetPersonaServiceTypes/getpersonaservice/types"
	GetPersonaCompendiumErrors "github.com/bradleyGamiMarques/PersonaCompendiumErrors"
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

	if personaName == "" {
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
			":personaName": &types.AttributeValueMemberS{Value: personaName},
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
		log.Printf("Not Found: no persona found with name: %s", personaName)
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
