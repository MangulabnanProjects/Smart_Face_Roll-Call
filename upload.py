import cv2
import numpy as np
from ultralytics import YOLO
import tkinter as tk
from tkinter import filedialog
import os

# --- CONFIGURATION ---
model_path = 'bestyolov11.pt' 
# Set extremely low to catch "shy" detections
confidence_threshold = 0.4
# Target width for the display window
DISPLAY_WIDTH = 800 

def select_image():
    """Opens a file dialog to let the user select an image."""
    root = tk.Tk()
    root.withdraw() 
    file_path = filedialog.askopenfilename(
        title="Select an Image to Scan",
        filetypes=[("Image files", "*.jpg *.jfif *.jpeg *.png *.bmp *.webp")]
    )
    root.destroy()
    return file_path

def apply_clahe(image):
    """
    Applies CLAHE (Contrast Limited Adaptive Histogram Equalization) 
    to help the model see faces in bad lighting.
    """
    # Convert to LAB color space
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    
    # Apply CLAHE to the L-channel
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    cl = clahe.apply(l)
    
    # Merge and convert back to BGR
    limg = cv2.merge((cl, a, b))
    final = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)
    return final

def resize_for_display(image, target_width):
    """Resizes image to fit screen while keeping aspect ratio."""
    if image is None: return None
    h, w = image.shape[:2]
    if w < target_width: return image
    aspect_ratio = h / w
    new_height = int(target_width * aspect_ratio)
    return cv2.resize(image, (target_width, new_height))

def main():
    # 1. Load Model
    try:
        print(f"Loading model from {model_path}...")
        model = YOLO(model_path)
    except Exception as e:
        print(f"Error loading model: {e}")
        return

    # 2. Select Image
    image_path = select_image()
    if not image_path:
        print("No image selected.")
        return

    # 3. Read & Preprocess
    original_image = cv2.imread(image_path)
    if original_image is None:
        print("Error reading image.")
        return

    print("Applying enhancement (CLAHE)...")
    # We use the enhanced image for PREDICTION so the model sees better
    enhanced_image = apply_clahe(original_image)

    # 4. Run Inference
    results = model(enhanced_image, conf=confidence_threshold)

    # 5. Process Detections
    # We plot the boxes on the ORIGINAL image for the final display
    # (so the colors look natural to the human eye, even if the model used the enhanced one)
    annotated_image = original_image.copy()
    
    # Check if we found anyone
    if len(results[0].boxes) == 0:
        print("No faces detected. Try lowering confidence_threshold further.")
    else:
        # Draw boxes
        annotated_image = results[0].plot()



    # 6. Display Main Result
    final_display = resize_for_display(annotated_image, DISPLAY_WIDTH)
    cv2.imshow("Main Detection Result", final_display)
    
    print("Press any key on the image window to exit...")
    cv2.waitKey(0)
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()