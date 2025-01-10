from flask import Flask, request, jsonify, render_template
import os

app = Flask(__name__)

def write_env_file(env_vars):
    with open('.env', 'w') as env_file:
        for key, value in env_vars.items():
            env_file.write(f'{key}={value}\n')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/account', methods=['POST'])
def account():
    data = request.get_json()
    account = data['account']
    network = data['network']
    rpc_url = data['rpcUrl']
    
    print('Received account:', account)
    print('Received network:', network)
    print('Received RPC URL:', rpc_url)
    
    # Write the wallet ID and RPC URL to the .env file manually
    env_vars = {
        'WALLET_ID': account,
        'RPC_URL': rpc_url
    }
    write_env_file(env_vars)

    os.environ['WALLET_ID'] = account
    os.environ['RPC_URL'] = rpc_url

    # Redirect to the success page
    return jsonify({'status': 'success', 'redirect': '/success', 'account': account, 'network': network, 'rpcUrl': rpc_url})

@app.route('/success')
def success():
    # Load the environment variables manually
    wallet_id = os.environ.get('WALLET_ID')
    rpc_url = os.environ.get('RPC_URL')
    network = "Sepolia Test Network"  # You can add more logic to determine the network name based on ID
    
    return render_template('success.html', wallet_id=wallet_id, network=network, rpc_url=rpc_url)

if __name__ == '__main__':
    app.run(debug=True)
