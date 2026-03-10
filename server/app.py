from flask import Flask, request, jsonify
from otp_store import otp_manager
from email_service import email_service
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.route("/send-otp", methods=["POST"])
def send_otp():
    data = request.get_json()
    email = data.get("email")
    
    if not email:
        return jsonify({"error": "Email is required"}), 400
    
    otp_code, error = otp_manager.generate_otp(email)
    if error:
        return jsonify({"error": error}), 429

    try:
        email_service.send_otp_email(email, otp_code)
        logger.info(f"OTP sent to {email}")
        return jsonify({"message": "OTP sent successfully"}), 200
    except Exception as e:
        logger.error(f"Failed to send email to {email}: {str(e)}")
        return jsonify({"error": "Failed to send email. Please try again later."}), 500

@app.route("/verify-otp", methods=["POST"])
def verify_otp():
    data = request.get_json()
    email = data.get("email")
    otp_code = data.get("otp_code")
    
    if not email or not otp_code:
        return jsonify({"error": "Email and OTP code are required"}), 400
    
    success, message = otp_manager.verify_otp(email, otp_code)
    
    if success:
        return jsonify({"message": message}), 200
    else:
        # Check status codes based on message (simpler for this case)
        if "No OTP" in message:
            return jsonify({"error": message}), 404
        elif "expired" in message:
            return jsonify({"error": message}), 410
        elif "Too many" in message:
            return jsonify({"error": message}), 403
        else:
            return jsonify({"error": message}), 401

if __name__ == "__main__":
    # In production, use a production server like Gunicorn
    app.run(host="0.0.0.0", port=5000, debug=True)
