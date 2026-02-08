FROM python:3.10-slim

# Set the working directory inside the container to be the "/app"
WORKDIR /app

# Copy the requirements.txt file into the container
COPY requirements.txt .

# We download the appropriate application dependencies
# Pip caches downloaded packages to speed up future installations 
# on your local machine, but in Docker containers this cache is 
# useless (since each build starts fresh) and just bloats the image 
# size, so --no-cache-dir prevents creating this unnecessary cached 
# data that increases your image from megabytes to potentially hundreds 
# of megabytes larger.
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Expose the port
EXPOSE 5000

# Set environment variable
ENV FLASK_APP=app.py

# Run the application
CMD ["python", "app.py"]