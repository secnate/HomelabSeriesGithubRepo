from flask import Flask, render_template
import os
import socket

app = Flask(__name__)

@app.route('/')
def home():
    hostname = socket.gethostname()
    cloud_provider = os.environ.get('CLOUD_PROVIDER', 'Unknown')

    # We now use the render_template() function to serve HTML files
    #
    # Per https://flask.palletsprojects.com/en/stable/api/#flask.render_template documentation,
    # the 'index.html' is the name of the template to render, while the subsequent variables
    # (cloud, hostname, version) are "context" variables to make available in the template
    return render_template('index.html', cloud=cloud_provider, hostname=hostname, version='1.0')

@app.route('/health')
def health():
    return { 'status' : 'healthy'}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)