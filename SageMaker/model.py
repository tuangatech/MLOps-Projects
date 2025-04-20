from torch import nn
from transformers import RobertaConfig, RobertaForSequenceClassification
from types import SimpleNamespace


configs = SimpleNamespace(
    max_len=64,           # Maximum sequence length for tokenization  ------ 128
    batch_size=16,        # Batch size for training
    learning_rate=2e-5,   # Learning rate for optimizer
    num_epochs=2,         # Number of training epochs
    dropout=0.3,          # Dropout rate for the model
    patience=3,           # Patience for early stopping
    random_seed=42,       # Random seed for reproducibility
    model_name="roberta-base"  # Pre-trained model name
)

class IntentClassifier(nn.Module):
    def __init__(self, num_intent_classes, model_name=configs.model_name, dropout=configs.dropout):
        super(IntentClassifier, self).__init__()

        # Store the configuration
        self.config = RobertaConfig.from_pretrained(model_name)
        self.config.num_labels = num_intent_classes
        self.config.dropout = dropout
        
        try:
            # First attempt: original approach with force_download and legacy format
            self.model = RobertaForSequenceClassification.from_pretrained(
                model_name,
                num_labels=num_intent_classes,
                hidden_dropout_prob=dropout,
                use_safetensors=False,
                force_download=True
            )
        except Exception as e:
            print(f"> Failed to load pre-trained weights with error: {e}")
            print("> Initializing model with configuration only (no pre-trained weights)")
            
            # Second approach: Initialize with configuration only
            self.model = RobertaForSequenceClassification(self.config)
            print("> Model initialized with random weights.")

    # forward pass to generate predictions
    def forward(self, input_ids, attention_mask):
        return self.model(input_ids=input_ids, attention_mask=attention_mask)
    