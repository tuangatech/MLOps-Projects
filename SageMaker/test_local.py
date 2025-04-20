import requests
import json

# Sample input
sample_input = {
    "texts": ["What is the status of my order?", "Can I change my shipping address?"]
}

# Send request to local container
try:
    response = requests.post(
        'http://localhost:8080/invocations',
        json=sample_input,
        headers={'Content-Type': 'application/json'}
    )
    
    # Print status code and response
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        print("Prediction result:")
        print(json.dumps(response.json(), indent=2))
    else:
        print("Error response:")
        print(response.text)
        
except Exception as e:
    print(f"Error sending request: {str(e)}")