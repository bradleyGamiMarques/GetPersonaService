package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	getpersonaservicetypes "github.com/bradleyGamiMarques/GetPersonaServiceTypes"
)

func HandleRequest(ctx context.Context, request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {

	// Extract the persona name from the path parameters
	personaName := request.PathParameters["personaName"]

	if personaName == "" {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 400,
			Body:       "personaName is required",
		}, nil
	}

	// Use os.Getenv to read the environment variable
	tableName := os.Getenv("DYNAMODB_TABLE_NAME")
	if tableName == "" {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       "Internal Server Error",
		}, nil
	}

	// Load the AWS default config
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       fmt.Sprintf("failed to load configuration, %v", err),
		}, nil
	}

	// Create a DynamoDB client
	svc := dynamodb.NewFromConfig(cfg)

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
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       fmt.Sprintf("Failed to query item: %v", err),
		}, nil
	}

	if len(result.Items) == 0 {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 404,
			Body:       fmt.Sprintf("There is no persona with that name: %s", personaName),
		}, nil
	}

	var response getpersonaservicetypes.GetP3RPersonaByNameResponse
	err = attributevalue.UnmarshalMap(result.Items[0], &response)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       fmt.Sprintf("Failed to unmarshal response: %v", err),
		}, nil
	}

	responseBody, err := json.Marshal(response)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       fmt.Sprintf("Failed to marshal response: %v", err),
		}, nil
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode: 200,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(responseBody),
	}, nil
}

func main() {
	lambda.Start(HandleRequest)
}
