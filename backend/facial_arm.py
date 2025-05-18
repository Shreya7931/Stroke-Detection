from flask import Flask, request, jsonify
import cv2
import mediapipe as mp
import numpy as np
import time
import os
from werkzeug.utils import secure_filename

app = Flask(__name__)
mp_pose = mp.solutions.pose
pose = mp_pose.Pose()

# Configuration
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'mp4', 'avi', 'mov'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def analyze_arm_symmetry(video_path):
    cap = cv2.VideoCapture(video_path)
    symmetrical_frames = 0
    total_frames = 0
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
            
        image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = pose.process(image)
        
        if results.pose_landmarks:
            landmarks = results.pose_landmarks.landmark
            frame_width = frame.shape[1]
            frame_height = frame.shape[0]
            
            # Get keypoints
            left_shoulder = (int(landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER].x * frame_width),
                            int(landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER].y * frame_height))
            right_shoulder = (int(landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER].x * frame_width),
                             int(landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER].y * frame_height))
            left_wrist = (int(landmarks[mp_pose.PoseLandmark.LEFT_WRIST].x * frame_width),
                         int(landmarks[mp_pose.PoseLandmark.LEFT_WRIST].y * frame_height))
            right_wrist = (int(landmarks[mp_pose.PoseLandmark.RIGHT_WRIST].x * frame_width),
                          int(landmarks[mp_pose.PoseLandmark.RIGHT_WRIST].y * frame_height))
            
            # Calculate midline
            mid_x = (left_shoulder[0] + right_shoulder[0]) // 2
            
            # Calculate distances from symmetry line
            left_dist = abs(left_wrist[0] - mid_x)
            right_dist = abs(right_wrist[0] - mid_x)
            
            # Symmetry check
            threshold = 20
            if abs(left_dist - right_dist) <= threshold:
                symmetrical_frames += 1
            total_frames += 1
    
    cap.release()
    
    if total_frames == 0:
        return {"error": "No frames processed"}
    
    symmetry_percentage = (symmetrical_frames / total_frames) * 100
    stroke_detected = symmetry_percentage < 70  # If less than 70% symmetrical, potential stroke
    
    return {
        "symmetry_percentage": symmetry_percentage,
        "stroke_detected": stroke_detected,
        "total_frames": total_frames,
        "symmetrical_frames": symmetrical_frames
    }

@app.route('/analyze-arm-symmetry', methods=['POST'])
def analyze_video():
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400
    
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        try:
            result = analyze_arm_symmetry(filepath)
            os.remove(filepath)  # Clean up after analysis
            return jsonify(result)
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    
    return jsonify({"error": "Invalid file type"}), 400

if __name__ == '__main__':
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    app.run(host='0.0.0.0', port=8000, debug=True)