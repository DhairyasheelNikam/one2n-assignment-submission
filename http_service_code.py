import boto3
from flask import Flask, jsonify
from botocore.exceptions import NoCredentialsError, ClientError

# Configuring the Basic Setup:
app = Flask(__name__)
s3 = boto3.client('s3')
S3_BUCKET_NAME = 'one2n-assignment-bucket'

# Function to List the S3 Contents:
def s3_content(prefix=''):
    try:
        response = s3.list_objects_v2(Bucket=S3_BUCKET_NAME, Prefix=prefix, Delimiter='/')
        directories = []
        files = []
        
        # Extracting Directories:
        if 'CommonPrefixes' in response:
            directories = [item['Prefix'][len(prefix):].strip('/') for item in response['CommonPrefixes']]

        # Extracting Files:
        if 'Contents' in response:
            files = [item['Key'][len(prefix):] for item in response['Contents']]
        
        content = directories + files
        
        content = [item for item in content if item]

        if not content and not ('Contents' in response or 'CommonPrefixes' in response):
            raise Exception(f"Directory '{prefix}' does not exist.")   
        return content

# Handling the Common Possible Errors:
    except NoCredentialsError:
        raise Exception("No AWS credentials found. Please set them up.")
    except ClientError as e:
        if e.response['Error']['Code'] == 'AccessDenied':
            raise Exception("Access denied. Please check your AWS S3 permissions.")
        else:
            raise Exception(f"AWS ClientError: {e.response['Error']['Message']}")
    except Exception as e:
        raise Exception(f"Error listing objects in S3 bucket: {str(e)}")

# Defining Route Parameters:
@app.route('/list-bucket-content/', methods=['GET'])
@app.route('/list-bucket-content/<path:prefix>', methods=['GET'])

# Function to get the Contents in the form of the desired Output:
def bucket_content(prefix=''):
    if prefix and not isinstance(prefix, str):
        return jsonify({"error": "Invalid prefix provided."}), 400
    
    if prefix and not prefix.endswith('/'):
        prefix += '/'
    
    try:
        content = s3_content(prefix)
        return jsonify({"content": content})
    
    except Exception as e:
        return jsonify({"error": str(e)}), 404

# Route Handling for Errors:
@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Not Found"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal Server Error"}), 500

# Running the Flask Web Application:
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)