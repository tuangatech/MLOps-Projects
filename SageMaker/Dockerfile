# FROM pytorch/pytorch:1.13.1-cuda11.6-cudnn8-runtime
# FROM 763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.0.1-gpu-py310-cu118-ubuntu20.04-sagemaker
FROM 763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.2.0-gpu-py310-cu118-ubuntu20.04-sagemaker

WORKDIR /opt/program

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy model files
COPY model.pth .
COPY model.py .
COPY label_encoder.pkl .
COPY inference.py .
COPY utils.py .

# Add a server script to handle SageMaker requests
COPY serve.py .

# Set up the program to run when the container is started
ENTRYPOINT ["python", "serve.py"]