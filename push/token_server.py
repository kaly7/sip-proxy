from flask import Flask, request, jsonify
import json, os

app = Flask(__name__)
TOKEN_FILE = '/opt/sip-push/tokens.json'

def load_tokens():
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE) as f:
            return json.load(f)
    return {}

def save_tokens(tokens):
    with open(TOKEN_FILE, 'w') as f:
        json.dump(tokens, f)

@app.route('/register-token', methods=['POST'])
def register_token():
    data = request.json
    user = data.get('user')
    token = data.get('token')
    if not user or not token:
        return jsonify({'error': 'missing fields'}), 400
    tokens = load_tokens()
    tokens[user] = token
    save_tokens(tokens)
    return jsonify({'ok': True})

@app.route('/get-token/<user>')
def get_token(user):
    tokens = load_tokens()
    token = tokens.get(user)
    if not token:
        return jsonify({'error': 'not found'}), 404
    return jsonify({'token': token})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9451)
