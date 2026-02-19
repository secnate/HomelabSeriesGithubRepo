# This Is A Sample Comment To Trigger the CI/CD Pipeline
from flask import Flask, render_template
import os
import socket

app = Flask(__name__)

@app.route('/')
def home():
    hostname = socket.gethostname()
    cloud_provider = os.environ.get('CLOUD_PROVIDER', 'Unknown')

    # Extract the secrets that were fed into the Flask application containers environment variables
    extracted_secrets = {
        'FEATURE_FLAG_BETA' : os.environ.get('FEATURE_FLAG_BETA'),
        'API_KEY' : os.environ.get('API_KEY'),
        'DATABASE_PASSWORD' : os.environ.get('DATABASE_PASSWORD'),
        'STRIPE_SECRET_KEY' : os.environ.get('STRIPE_SECRET_KEY'),
        'APP_ENV' : os.environ.get('APP_ENV')
    }

    # We now use the render_template() function to serve HTML files
    #
    # Per https://flask.palletsprojects.com/en/stable/api/#flask.render_template documentation,
    # the 'index.html' is the name of the template to render, while the subsequent variables
    # (cloud, hostname, version) are "context" variables to make available in the template
    return render_template('index.html', cloud=cloud_provider, hostname=hostname, version='2.0', **extracted_secrets)

@app.route('/health')
def health():
    return { 'status' : 'healthy'}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)