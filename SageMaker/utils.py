import re 
import nltk
from nltk.corpus import stopwords

nltk.download('stopwords')


# Preprocessing
def preprocess_text(text):
    # Remove numbers and special characters
    text = re.sub(r'[^A-Za-z\s]', '', text)
    
    # Convert to lowercase and split into words based on whitespace
    words = text.lower().split()

    # Remove stopwords
    stop_words = set(stopwords.words('english'))
    words = [word for word in words if word not in stop_words]

    # Join words back into a single string
    return ' '.join(words)
