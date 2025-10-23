import os
import firebase_admin
from firebase_functions import https_fn
from firebase_admin import firestore, auth
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow # Necesitarás 'pip install google-auth-oauthlib'

firebase_admin.initialize_app()
db = firestore.client()

# ¡ESTOS VAN EN SECRET MANAGER! (No en el código)
CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID')
CLIENT_SECRET = os.environ.get('GOOGLE_CLIENT_SECRET')

# Esta es la URL de tu función HTTP desplegada
REDIRECT_URI = "https" 

@https_fn.on_request # O usa el decorador antiguo si usas 1st Gen
def exchangeAuthCode(req: https_fn.Request) -> https_fn.Response:
    """
    Recibe un authCode de Flutter, lo intercambia por un 
    refresh_token y lo guarda en Firestore.
    """
    # 1. Verifica que el usuario esté autenticado en Firebase
    try:
        auth_header = req.headers.get("authorization", "").split(" ")
        if len(auth_header) != 2 or auth_header[0].lower() != "bearer":
            return https_fn.Response("Unauthorized", status=401)

        token = auth_header[1]
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
    except Exception as e:
        return https_fn.Response(f"Auth error: {e}", status=401)

    # 2. Obtiene los datos del body
    try:
        data = req.get_json()
        auth_code = data['authCode']
        fcm_token = data['fcmToken']
        if not auth_code or not fcm_token:
            return https_fn.Response("Missing authCode or fcmToken", status=400)
    except Exception as e:
        return https_fn.Response(f"Invalid JSON: {e}", status=400)

    # 3. Intercambia el código por tokens
    try:
        flow = Flow.from_client_config(
            client_config={
                "web": {
                    "client_id": CLIENT_ID,
                    "client_secret": CLIENT_SECRET,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                }
            },
            scopes=None, # Los scopes ya se pidieron en el cliente
            redirect_uri=REDIRECT_URI 
        )

        # Aquí ocurre la magia: Google te da los tokens
        flow.fetch_token(code=auth_code)
        creds = flow.credentials

        refresh_token = creds.refresh_token

        if not refresh_token:
             return https_fn.Response("No refresh_token received. Asegúrate de pedir 'offline access'.", status=400)

        # 4. Guarda los tokens en Firestore
        user_doc_ref = db.collection('users').document(user_id)
        user_doc_ref.set({
            'refresh_token': refresh_token,
            'fcm_token': fcm_token
            # ...otros datos del usuario
        }, merge=True)

        return https_fn.Response("Auth successful!", status=200)

    except Exception as e:
        return https_fn.Response(f"Error exchanging token: {e}", status=500)