import requests


def lambda_handler(event, context):
    print(event)

    try:
        response = requests.get('https://ml.kat-sample-domain.link')
        print(response.json())
    except Exception as e:
        print('error')
        print(e)

    
    return {
        'statusCode': 200,
        'body': 'Hello from Lambda!'
    }