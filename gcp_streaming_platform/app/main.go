package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"cloud.google.com/go/pubsub"
)

var ctx = context.Background()

type PublishDataStruct struct {
	Key string
	Value int32
}

func PubSubInit() (*pubsub.Client, error) {

	projcetId := os.Getenv("PROJECT_ID")

	client, err := pubsub.NewClient(ctx, projcetId)
	
	if err != nil {
		fmt.Println(err)
		return nil, err
	}

	return client, nil
}
func handler(w http.ResponseWriter, r *http.Request) {
	client, err := PubSubInit()
	if err != nil {
		fmt.Println(err)
		return
	}

	defer client.Close()

	topicName := os.Getenv("TOPIC_NAME")
	topic := client.Topic(topicName)

	data := PublishDataStruct{
		Key: "name",
		Value: 1,
	}
	jsonData, err := json.Marshal(data)
	
	if err != nil {
		fmt.Println(err)
		return
	}
	
	result := topic.Publish(ctx, &pubsub.Message{
		Data: []byte(jsonData),
	})

	id, err := result.Get(ctx)
	if err != nil {
		fmt.Println(err)
		return
	}

	fmt.Fprintf(w, "Hello World! " + id)
	// publish message
}

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}
