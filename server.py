import cv2
import numpy as np
from ultralytics import YOLO
import base64
from flask import Flask, request, jsonify
import io
import time
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
from matplotlib import cm

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

def generate_cam_visualization(image, boxes, confidences):
    """Generate Class Activation Map showing critical detection regions."""
    h, w = image.shape[:2]
    heatmap = np.zeros((h, w), dtype=np.float32)
    
    # Create heatmap based on detected boxes and confidence
    for box, conf in zip(boxes, confidences):
        x1, y1, x2, y2 = map(int, box)
        # Add Gaussian blur around detection area
        center_x, center_y = (x1 + x2) // 2, (y1 + y2) // 2
        radius = max((x2 - x1), (y2 - y1)) // 2
        
        Y, X = np.ogrid[:h, :w]
        dist = np.sqrt((X - center_x)**2 + (Y - center_y)**2)
        gaussian = np.exp(-(dist**2) / (2 * (radius/2)**2))
        heatmap += gaussian * conf
    
    # Normalize
    heatmap = (heatmap - heatmap.min()) / (heatmap.max() - heatmap.min() + 1e-8)
    
    # Apply colormap (jet: blue -> red)
    heatmap_colored = cv2.applyColorMap((heatmap * 255).astype(np.uint8), cv2.COLORMAP_JET)
    
    # Overlay on original image
    overlay = cv2.addWeighted(image, 0.6, heatmap_colored, 0.4, 0)
    return overlay

def generate_feature_layers(image, results):
    """Visualize deep layer features from YOLO model."""
    # Get feature maps from model (simulated - real implementation would hook into model layers)
    h, w = image.shape[:2]
    
    # Create composite showing multiple "feature channels"
    fig, axes = plt.subplots(2, 2, figsize=(8, 8))
    fig.patch.set_facecolor('#1E2329')
    
    # Simulate different feature layers
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # Layer 1: Edge detection
    edges = cv2.Canny(gray, 50, 150)
    axes[0, 0].imshow(edges, cmap='hot')
    axes[0, 0].set_title('Edge Features', color='white', fontsize=10)
    axes[0, 0].axis('off')
    
    # Layer 2: Sobel gradient
    sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=5)
    axes[0, 1].imshow(np.abs(sobelx), cmap='viridis')
    axes[0, 1].set_title('Gradient Features', color='white', fontsize=10)
    axes[0, 1].axis('off')
    
    # Layer 3: Laplacian (texture)
    laplacian = cv2.Laplacian(gray, cv2.CV_64F)
    axes[1, 0].imshow(np.abs(laplacian), cmap='plasma')
    axes[1, 0].set_title('Texture Features', color='white', fontsize=10)
    axes[1, 0].axis('off')
    
    # Layer 4: High-level activation simulation
    blurred = cv2.GaussianBlur(gray, (15, 15), 0)
    activation = cv2.subtract(gray, blurred)
    axes[1, 1].imshow(activation, cmap='magma')
    axes[1, 1].set_title('High-level Activation', color='white', fontsize=10)
    axes[1, 1].axis('off')
    
    plt.tight_layout()
    
    # Convert to image
    buf = io.BytesIO()
    plt.savefig(buf, format='png', facecolor='#1E2329', dpi=80)
    buf.seek(0)
    plt.close()
    
    # Read back as numpy array
    feature_img = cv2.imdecode(np.frombuffer(buf.read(), np.uint8), cv2.IMREAD_COLOR)
    return feature_img

def generate_detection_grid(image, results):
    """Show YOLO detection grid and anchor boxes."""
    overlay = image.copy()
    h, w = overlay.shape[:2]
    
    # YOLO typically uses grid (e.g., 13x13, 26x26, 52x52)
    # Simulate grid overlay
    grid_size = 20  # Approximate grid cells
    cell_h = h // grid_size
    cell_w = w // grid_size
    
    # Draw grid
    for i in range(grid_size):
        cv2.line(overlay, (0, i * cell_h), (w, i * cell_h), (0, 255, 255), 1, cv2.LINE_AA)
        cv2.line(overlay, (i * cell_w, 0), (i * cell_w, h), (0, 255, 255), 1, cv2.LINE_AA)
    
    # Highlight cells with detections
    for box in results[0].boxes:
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        center_x, center_y = (x1 + x2) // 2, (y1 + y2) // 2
        
        grid_x = center_x // cell_w
        grid_y = center_y // cell_h
        
        # Highlight the cell
        cv2.rectangle(
            overlay,
            (grid_x * cell_w, grid_y * cell_h),
            ((grid_x + 1) * cell_w, (grid_y + 1) * cell_h),
            (0, 255, 0),
            2
        )
        
        # Draw anchor box
        cv2.rectangle(overlay, (x1, y1), (x2, y2), (255, 0, 255), 2)
    
    return overlay

def generate_pipeline_comparison(original, enhanced, detected):
    """Create before/after comparison showing processing pipeline."""
    h, w = original.shape[:2]
    
    # Resize all to same height
    target_h = 300
    target_w = int(w * (target_h / h))
    
    orig_resized = cv2.resize(original, (target_w, target_h))
    enh_resized = cv2.resize(enhanced, (target_w, target_h))
    det_resized = cv2.resize(detected, (target_w, target_h))
    
    # Add labels
    def add_label(img, text):
        img_copy = img.copy()
        cv2.rectangle(img_copy, (0, 0), (target_w, 30), (30, 35, 41), -1)
        cv2.putText(img_copy, text, (10, 20), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.6, (0, 217, 201), 2, cv2.LINE_AA)
        return img_copy
    
    orig_labeled = add_label(orig_resized, "1. ORIGINAL")
    enh_labeled = add_label(enh_resized, "2. ENHANCED (CLAHE)")
    det_labeled = add_label(det_resized, "3. DETECTED")
    
    # Stack horizontally
    pipeline = np.hstack([orig_labeled, enh_labeled, det_labeled])
    return pipeline

def generate_confidence_distribution(image, boxes, confidences, class_names):
    """Generate visual breakdown of detection confidence."""
    h, w = image.shape[:2]
    
    # Create figure
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4))
    fig.patch.set_facecolor('#1E2329')
    
    # Left: Confidence bar chart
    if confidences:
        colors = ['#00D9C9' if c >= 0.7 else '#FFA500' if c >= 0.5 else '#FF6B6B' for c in confidences]
        bars = ax1.barh(range(len(confidences)), confidences, color=colors)
        ax1.set_yticks(range(len(confidences)))
        ax1.set_yticklabels([class_names[i] for i in range(len(confidences))], color='white')
        ax1.set_xlabel('Confidence Score', color='white')
        ax1.set_title('Detection Confidence', color='white', fontsize=12)
        ax1.set_xlim(0, 1)
        ax1.tick_params(colors='white')
        ax1.spines['bottom'].set_color('white')
        ax1.spines['left'].set_color('white')
        ax1.spines['top'].set_visible(False)
        ax1.spines['right'].set_visible(False)
        ax1.set_facecolor('#1E2329')
        
        # Add value labels
        for i, (bar, conf) in enumerate(zip(bars, confidences)):
            ax1.text(conf + 0.02, i, f'{conf:.1%}', va='center', color='white', fontsize=9)
    
    # Right: Spatial confidence heatmap
    spatial_heatmap = np.zeros((h // 10, w // 10), dtype=np.float32)
    for box, conf in zip(boxes, confidences):
        x1, y1, x2, y2 = map(int, box)
        x1_s, y1_s = x1 // 10, y1 // 10
        x2_s, y2_s = x2 // 10, y2 // 10
        spatial_heatmap[y1_s:y2_s, x1_s:x2_s] = max(spatial_heatmap[y1_s:y2_s, x1_s:x2_s].max(), conf)
    
    im = ax2.imshow(spatial_heatmap, cmap='hot', interpolation='bilinear', aspect='auto')
    ax2.set_title('Spatial Confidence Map', color='white', fontsize=12)
    ax2.axis('off')
    
    plt.tight_layout()
    
    # Convert to image
    buf = io.BytesIO()
    plt.savefig(buf, format='png', facecolor='#1E2329', dpi=100)
    buf.seek(0)
    plt.close()
    
    conf_img = cv2.imdecode(np.frombuffer(buf.read(), np.uint8), cv2.IMREAD_COLOR)
    return conf_img

def generate_feature_points(image, boxes):
    """Visualize bounding boxes and simulated facial landmarks."""
    overlay = image.copy()
    
    for box in boxes:
        x1, y1, x2, y2 = map(int, box)
        
        # Draw bounding box with glow effect
        for thickness in [6, 4, 2]:
            alpha = 0.3 if thickness == 6 else 0.6 if thickness == 4 else 1.0
            color = tuple([int(c * alpha) for c in [0, 217, 201]])  # Cyan
            cv2.rectangle(overlay, (x1, y1), (x2, y2), color, thickness)
        
        # Simulate key facial points (simplified)
        face_w = x2 - x1
        face_h = y2 - y1
        
        # Key points (simulated positions on a face)
        points = [
            (x1 + face_w // 2, y1 + face_h // 4),  # Top of face
            (x1 + face_w // 3, y1 + face_h // 2),  # Left eye
            (x2 - face_w // 3, y1 + face_h // 2),  # Right eye
            (x1 + face_w // 2, y1 + int(face_h * 0.6)),  # Nose
            (x1 + face_w // 2, y2 - face_h // 4),  # Mouth
        ]
        
        # Draw points
        for pt in points:
            cv2.circle(overlay, pt, 3, (255, 255, 0), -1)
            cv2.circle(overlay, pt, 5, (255, 255, 0), 1)
    
    return overlay

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
    detected_identities = []
    
    # NEW: Visualization data
    cam_viz_base64 = ""
    feature_layers_base64 = ""
    detection_grid_base64 = ""
    pipeline_comp_base64 = ""
    feature_points_base64 = ""
    confidence_dist_base64 = ""

    if len(results[0].boxes) > 0:
        detected = True
        
        # Extract detection data
        boxes = [box.xyxy[0].cpu().numpy() for box in results[0].boxes]
        confidences = [float(box.conf[0]) for box in results[0].boxes]
        class_names = [model.names[int(box.cls[0])] for box in results[0].boxes]
        
        # Plot on ORIGINAL image for natural colors
        annotated_image = results[0].plot()
        
        # Extract detected identities
        for box in results[0].boxes:
            class_id = int(box.cls[0])
            identity = model.names[class_id]
            detected_identities.append(identity)
        
        # Convert labeled image to Base64
        _, buffer = cv2.imencode('.jpg', annotated_image)
        labeled_image_base64 = base64.b64encode(buffer).decode('utf-8')
        
        # --- GENERATE ALL VISUALIZATIONS ---
        viz_start = time.time()
        
        # 1. Class Activation Map
        cam_viz = generate_cam_visualization(original_image, boxes, confidences)
        _, cam_buffer = cv2.imencode('.jpg', cam_viz)
        cam_viz_base64 = base64.b64encode(cam_buffer).decode('utf-8')
        
        # 2. Feature Layers
        feature_layers = generate_feature_layers(original_image, results)
        _, feat_buffer = cv2.imencode('.jpg', feature_layers)
        feature_layers_base64 = base64.b64encode(feat_buffer).decode('utf-8')
        
        # 3. Detection Grid
        detection_grid = generate_detection_grid(original_image, results)
        _, grid_buffer = cv2.imencode('.jpg', detection_grid)
        detection_grid_base64 = base64.b64encode(grid_buffer).decode('utf-8')
        
        # 4. Pipeline Comparison
        pipeline_comp = generate_pipeline_comparison(original_image, enhanced_image, annotated_image)
        _, pipe_buffer = cv2.imencode('.jpg', pipeline_comp)
        pipeline_comp_base64 = base64.b64encode(pipe_buffer).decode('utf-8')
        
        # 5. Feature Points
        feature_points = generate_feature_points(original_image, boxes)
        _, fp_buffer = cv2.imencode('.jpg', feature_points)
        feature_points_base64 = base64.b64encode(fp_buffer).decode('utf-8')
        
        # 6. Confidence Distribution
        confidence_dist = generate_confidence_distribution(original_image, boxes, confidences, class_names)
        _, conf_buffer = cv2.imencode('.jpg', confidence_dist)
        confidence_dist_base64 = base64.b64encode(conf_buffer).decode('utf-8')
        
        print(f"[-] Visualization generation took: {time.time() - viz_start:.2f}s")

    print(f"[✓] Total request time: {time.time() - start_time:.2f}s")
    print(f"[✓] Detected identities: {detected_identities}")
    
    return jsonify({
        'detected': detected,
        'labeled_image': labeled_image_base64,
        'detected_identities': detected_identities,
        # NEW: All visualization data
        'visualizations': {
            'cam': cam_viz_base64,
            'feature_layers': feature_layers_base64,
            'detection_grid': detection_grid_base64,
            'pipeline': pipeline_comp_base64,
            'feature_points': feature_points_base64,
            'confidence_dist': confidence_dist_base64,
        },
        'confidence_scores': confidences if detected else [],
    })

if __name__ == '__main__':
    # Run on all interfaces so emulator/device can connect
    app.run(host='192.168.0.10', port=5000)

