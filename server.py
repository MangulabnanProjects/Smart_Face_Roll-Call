import cv2
import numpy as np
from ultralytics import YOLO
import base64
from flask import Flask, request, jsonify
import io
import time

app = Flask(__name__)

# --- CONFIGURATION ---
model_path = 'bestyolov11.pt'
confidence_threshold = 0.4

print(f"Loading model from {model_path}...")
try:
    model = YOLO(model_path)
    print("Model loaded successfully.")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

def apply_clahe(image):
    """Applies CLAHE to help the model see faces in bad lighting."""
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    cl = clahe.apply(l)
    limg = cv2.merge((cl, a, b))
    final = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)
    return final

@app.route('/detect', methods=['POST'])
def detect():
    start_time = time.time()
    if not model:
        return jsonify({'error': 'Model not loaded'}), 500

    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    file = request.files['image']
    file_bytes = np.frombuffer(file.read(), np.uint8)
    original_image = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

    if original_image is None:
        return jsonify({'error': 'Invalid image'}), 400

    print(f"[-] Image received: {original_image.shape} in {time.time() - start_time:.2f}s")

    # Preprocess
    enhanced_image = apply_clahe(original_image)

    # Inference
    inf_start = time.time()
    results = model(enhanced_image, conf=confidence_threshold)
    print(f"[-] Inference took: {time.time() - inf_start:.2f}s")
    
    detected = False
    labeled_image_base64 = ""
    detected_identities = []  # NEW: List of detected student identities

    if len(results[0].boxes) > 0:
        detected = True
        # Plot on ORIGINAL image for natural colors
        annotated_image = results[0].plot()
        
        # Extract detected identities from class names
        for box in results[0].boxes:
            class_id = int(box.cls[0])
            identity = model.names[class_id]  # Get the class name (e.g., "nix", "jc", "mc")
            detected_identities.append(identity)
        
        # Convert to Base64
        _, buffer = cv2.imencode('.jpg', annotated_image)
        labeled_image_base64 = base64.b64encode(buffer).decode('utf-8')

    print(f"[✓] Total request time: {time.time() - start_time:.2f}s")
    print(f"[✓] Detected identities: {detected_identities}")
    return jsonify({
        'detected': detected,
        'labeled_image': labeled_image_base64,
        'detected_identities': detected_identities  # NEW: Return list of identities
    })

if __name__ == '__main__':
    # Run on all interfaces so emulator/device can connect
    app.run(host='192.168.0.10', port=5000)
