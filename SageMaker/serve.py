import os
import json
import flask
import traceback
import logging
from inference import model_fn, input_fn, predict_fn, output_fn

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# The flask app for serving predictions
app = flask.Flask(__name__)

# Load model at startup
model_dir = os.environ.get('SM_MODEL_DIR', '.')
logger.info(f"Loading model from {model_dir}")
model = model_fn(model_dir)
logger.info("Model loaded successfully\n")

@app.route('/ping', methods=['GET'])
def ping():
    """Health check endpoint for SageMaker"""
    return flask.Response(response=json.dumps({"status": "Healthy"}), status=200, mimetype='application/json')

@app.route('/invocations', methods=['POST'])
def invoke():
    """Handle prediction requests"""
    try:
        # Get input data
        content_type = flask.request.content_type
        request_body = flask.request.data.decode('utf-8')
        logger.info(f"Received request with content type: {content_type}")
        
        # Process input
        input_data = input_fn(request_body, content_type)
        logger.info(f"Input processed successfully: {input_data}\n")
        
        # Make prediction
        predictions = predict_fn(input_data, model)
        logger.info("Prediction completed")
        
        # Process output
        response = output_fn(predictions, 'application/json')
        logger.info("Response formatted")
        
        return flask.Response(response=response, status=200, mimetype='application/json')
    
    except Exception as e:
        error_message = f"Error during prediction: {str(e)}\n{traceback.format_exc()}"
        logger.error(error_message)
        return flask.Response(
            response=json.dumps({"error": str(e), "traceback": traceback.format_exc()}),
            status=500,
            mimetype='application/json'
        )

if __name__ == '__main__':
    # Run the server
    port = int(os.environ.get('SM_PORT', 8080))
    logger.info(f"Starting server on port {port}")
    app.run(host='0.0.0.0', port=port)