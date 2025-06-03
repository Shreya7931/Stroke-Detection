# main.py - Improved Stroke Detection System

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import cv2
import mediapipe as mp
import os
import shutil
import numpy as np
from twilio.rest import Client
from typing import List
import time
import math
from collections import deque
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
TWILIO_SID = os.getenv('TWILIO_SID')
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN')
TWILIO_PHONE = os.getenv('TWILIO_PHONE')

twilio_client = Client(TWILIO_SID, TWILIO_AUTH_TOKEN) if TWILIO_SID else None

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# MediaPipe setup
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False, 
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5
)

mp_pose = mp.solutions.pose
pose = mp_pose.Pose(
    static_image_mode=False,
    model_complexity=1,
    smooth_landmarks=True,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5
)

# Directory setup
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Enhanced facial landmark pairs for better symmetry detection
FACIAL_SYMMETRY_PAIRS = [
    (234, 454), (227, 447), (137, 366),  # Cheek landmarks
    (130, 359), (133, 362), (145, 374),  # Eye region
    (61, 291), (84, 314), (17, 18), (200, 199),  # Mouth region
    (172, 397), (136, 365), (150, 379),  # Jawline
    (98, 327), (115, 344),  # Nose region
]

class SymmetryAnalyzer:
    def __init__(self):
        self.face_history = deque(maxlen=30)
        self.arm_history = deque(maxlen=60)
        
    def calculate_angle(self, p1, p2, p3):
        """Calculate angle between three points"""
        a = np.array([p1.x, p1.y])
        b = np.array([p2.x, p2.y])
        c = np.array([p3.x, p3.y])
        
        ba = a - b
        bc = c - b
        
        cosine_angle = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc) + 1e-8)
        angle = np.arccos(np.clip(cosine_angle, -1.0, 1.0))
        return np.degrees(angle)
    
    def calculate_distance(self, p1, p2):
        """Calculate Euclidean distance between two points"""
        return math.sqrt((p1.x - p2.x)**2 + (p1.y - p2.y)**2)
    
    def calculate_enhanced_face_symmetry(self, frame):
        """Enhanced face symmetry calculation with multiple metrics"""
        try:
            img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(img_rgb)

            if not results.multi_face_landmarks:
                return None

            landmarks = results.multi_face_landmarks[0].landmark
            
            # Calculate multiple symmetry metrics
            distance_diffs = []
            for left_idx, right_idx in FACIAL_SYMMETRY_PAIRS:
                left_point = landmarks[left_idx]
                right_point = landmarks[right_idx]
                
                left_dist = abs(left_point.x - 0.5)  # Face center at 0.5
                right_dist = abs(right_point.x - 0.5)
                y_factor = 1 + abs(left_point.y - 0.5) * 0.5
                diff = abs(left_dist - right_dist) / y_factor
                distance_diffs.append(diff)
            
            face_width = abs(landmarks[234].x - landmarks[454].x) + 1e-6
            avg_distance_diff = np.mean(distance_diffs)
            distance_symmetry = max(0, 1 - (avg_distance_diff / (face_width * 0.5)))
            
            return max(0, min(1, distance_symmetry))
        except Exception as e:
            logger.error(f"Error in face symmetry calculation: {e}")
            return None
    
    def calculate_enhanced_arm_symmetry(self, landmarks, frame_shape):
        """Enhanced arm symmetry calculation"""
        try:
            left_shoulder = landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER]
            right_shoulder = landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER]
            left_wrist = landmarks[mp_pose.PoseLandmark.LEFT_WRIST]
            right_wrist = landmarks[mp_pose.PoseLandmark.RIGHT_WRIST]
            
            min_visibility = 0.5
            required_landmarks = [left_shoulder, right_shoulder, left_wrist, right_wrist]
            if any(lm.visibility < min_visibility for lm in required_landmarks):
                return None
            
            # Height symmetry
            shoulder_midpoint_y = (left_shoulder.y + right_shoulder.y) / 2
            left_wrist_height = abs(left_wrist.y - shoulder_midpoint_y)
            right_wrist_height = abs(right_wrist.y - shoulder_midpoint_y)
            height_diff = abs(left_wrist_height - right_wrist_height)
            height_symmetry = max(0, 1 - (height_diff * 4))
            
            # Distance symmetry
            body_center_x = (left_shoulder.x + right_shoulder.x) / 2
            left_wrist_dist = abs(left_wrist.x - body_center_x)
            right_wrist_dist = abs(right_wrist.x - body_center_x)
            dist_diff = abs(left_wrist_dist - right_wrist_dist)
            distance_symmetry = max(0, 1 - (dist_diff * 3))
            
            combined_symmetry = (height_symmetry * 0.5 + distance_symmetry * 0.5)
            return max(0, min(1, combined_symmetry))
        except Exception as e:
            logger.error(f"Error in arm symmetry calculation: {e}")
            return None

analyzer = SymmetryAnalyzer()

@app.post("/analyze-face/")
async def analyze_face_from_frames(frames: List[UploadFile] = File(...)):
    """Analyze face symmetry from uploaded frames"""
    try:
        if not frames:
            raise HTTPException(status_code=400, detail="No frames provided")
        
        symmetry_scores = []
        processed_frames = 0
        
        for frame in frames:
            try:
                contents = await frame.read()
                nparr = np.frombuffer(contents, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                
                if img is None:
                    continue
                    
                score = analyzer.calculate_enhanced_face_symmetry(img)
                if score is not None:
                    symmetry_scores.append(score)
                    processed_frames += 1
            except Exception as e:
                logger.warning(f"Error processing frame: {e}")
                continue
        
        if not symmetry_scores:
            return JSONResponse(content={
                "stroke_detected": False,
                "message": "No valid face detections in provided frames"
            }, status_code=400)
        
        # Apply temporal smoothing
        if len(symmetry_scores) > 5:
            smoothed_scores = []
            for i in range(len(symmetry_scores)):
                window = symmetry_scores[max(0, i-2):min(len(symmetry_scores), i+3)]
                smoothed_scores.append(np.median(window))
            symmetry_scores = smoothed_scores
        
        avg_symmetry = float(np.mean(symmetry_scores))
        stroke_detected = avg_symmetry < 0.75  # Threshold
        
        return JSONResponse(content={
            "stroke_detected": stroke_detected,
            "avg_symmetry": avg_symmetry,
            "frames_processed": processed_frames,
            "threshold_used": 0.75
        })
        
    except Exception as e:
        logger.error(f"Face analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze-arm/")
async def analyze_arm_from_frames(frames: List[UploadFile] = File(...)):
    """Analyze arm symmetry from uploaded frames"""
    try:
        if not frames:
            raise HTTPException(status_code=400, detail="No frames provided")
        
        symmetry_scores = []
        processed_frames = 0
        
        for frame in frames:
            try:
                contents = await frame.read()
                nparr = np.frombuffer(contents, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                
                if img is None:
                    continue
                    
                img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                results = pose.process(img_rgb)
                
                if results.pose_landmarks:
                    score = analyzer.calculate_enhanced_arm_symmetry(
                        results.pose_landmarks.landmark, 
                        img.shape
                    )
                    if score is not None:
                        symmetry_scores.append(score)
                        processed_frames += 1
            except Exception as e:
                logger.warning(f"Error processing frame: {e}")
                continue
        
        if not symmetry_scores:
            return JSONResponse(content={
                "stroke_detected": False,
                "message": "No valid pose detections in provided frames"
            }, status_code=400)
        
        # Apply temporal smoothing
        if len(symmetry_scores) > 5:
            smoothed_scores = []
            for i in range(len(symmetry_scores)):
                window = symmetry_scores[max(0, i-2):min(len(symmetry_scores), i+3)]
                smoothed_scores.append(np.median(window))
            symmetry_scores = smoothed_scores
        
        avg_symmetry = float(np.mean(symmetry_scores))
        stroke_detected = avg_symmetry < 0.7  # Threshold
        
        return JSONResponse(content={
            "stroke_detected": stroke_detected,
            "symmetry_percentage": avg_symmetry * 100,
            "frames_processed": processed_frames,
            "threshold_used": 70.0
        })
        
    except Exception as e:
        logger.error(f"Arm analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Initialize analyzer
analyzer = SymmetryAnalyzer()

def analyze_speech(audio_path: str):
    """Placeholder for speech analysis - would need speech processing library"""
    # This would require implementation with speech recognition and analysis
    # For now, returning default values
    return {"stroke_detected": False, "confidence": 0.0}

def send_sms(to_number: str, message: str):
    """Send SMS notification"""
    if not twilio_client:
        logger.warning("Twilio client not configured")
        return None
        
    try:
        message = twilio_client.messages.create(
            body=message,
            from_=TWILIO_PHONE,
            to=to_number
        )
        return message.sid
    except Exception as e:
        logger.error(f"Failed to send SMS: {e}")
        return None

# Modified backend endpoints with proper timing synchronization

@app.post("/analyze-face/")
async def analyze_face_live():
    """Live face symmetry analysis with improved timing"""
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        return JSONResponse(content={"error": "Could not open camera"}, status_code=500)

    # Optimize camera settings
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 15)
    
    # ADD: Camera warm-up period
    logger.info("Warming up camera...")
    for _ in range(10):  # Skip first 10 frames for camera stabilization
        ret, frame = cap.read()
        if not ret:
            break
    
    # ADD: Wait for frontend signal or use consistent timing
    duration = 5  # Match frontend duration EXACTLY
    logger.info(f"Starting face analysis for {duration} seconds...")
    
    start_time = time.time()
    symmetry_scores = []
    frame_count = 0
    
    # ADD: More frequent sampling for better accuracy
    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
                
            current_time = time.time() - start_time
            
            # Only analyze frames after 1 second to allow positioning
            if current_time >= 1.0:
                frame_count += 1
                
                # Process EVERY frame during active period for maximum accuracy
                score = analyzer.calculate_enhanced_face_symmetry(frame)
                if score is not None:
                    symmetry_scores.append(score)
                    logger.debug(f"Frame {frame_count}: Symmetry score = {score:.3f}")

            if current_time > duration:
                break

    finally:
        cap.release()
        cv2.destroyAllWindows()

    logger.info(f"Face analysis completed. Processed {len(symmetry_scores)} frames")
    
    if not symmetry_scores:
        return JSONResponse(content={
            "stroke_detected": False, 
            "stroke_ratio": 0.0, 
            "message": "No face detected during test."
        })

    # Enhanced analysis with outlier removal
    if len(symmetry_scores) > 10:
        # Remove outliers (top and bottom 10%)
        sorted_scores = sorted(symmetry_scores)
        trim_count = len(sorted_scores) // 10
        if trim_count > 0:
            symmetry_scores = sorted_scores[trim_count:-trim_count]
    
    avg_symmetry = float(np.mean(symmetry_scores))
    std_symmetry = float(np.std(symmetry_scores))
    median_symmetry = float(np.median(symmetry_scores))
    
    # More conservative threshold for better accuracy
    base_threshold = 0.75  # Lowered threshold
    stroke_detected = avg_symmetry < base_threshold
    stroke_ratio = max(0, 1 - avg_symmetry)
    
    logger.info(f"Face Analysis Results:")
    logger.info(f"  - Average Symmetry: {avg_symmetry:.3f}")
    logger.info(f"  - Median Symmetry: {median_symmetry:.3f}")
    logger.info(f"  - Std Deviation: {std_symmetry:.3f}")
    logger.info(f"  - Stroke Detected: {stroke_detected}")

    return JSONResponse(content={
        "stroke_detected": stroke_detected, 
        "stroke_ratio": stroke_ratio,
        "avg_symmetry": avg_symmetry,
        "median_symmetry": median_symmetry,
        "frames_processed": len(symmetry_scores),
        "symmetry_variability": std_symmetry,
        "threshold_used": base_threshold
    })

@app.post("/analyze-arm/")
async def analyze_arm_live():
    """Live arm symmetry analysis with enhanced detection"""
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        return JSONResponse(content={"error": "Could not open camera"}, status_code=500)
        
    # Optimize camera settings
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 15)
    
    # Camera warm-up
    logger.info("Warming up camera for arm test...")
    for _ in range(10):
        ret, frame = cap.read()
        if not ret:
            break
    
    duration = 15  # Match frontend duration EXACTLY
    logger.info(f"Starting arm analysis for {duration} seconds...")
    
    start_time = time.time()
    symmetry_scores = []
    frame_count = 0
    pose_detected_frames = 0

    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            current_time = time.time() - start_time
            
            # Start analyzing after 2 seconds for arm positioning
            if current_time >= 2.0:
                frame_count += 1
                
                # Process every frame for maximum accuracy
                image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = pose.process(image)

                if results.pose_landmarks:
                    pose_detected_frames += 1
                    score = analyzer.calculate_enhanced_arm_symmetry(
                        results.pose_landmarks.landmark, 
                        frame.shape
                    )
                    if score is not None:
                        symmetry_scores.append(score)
                        logger.debug(f"Frame {frame_count}: Arm symmetry = {score:.3f}")

            if current_time > duration:
                break

    finally:
        cap.release()
        cv2.destroyAllWindows()

    logger.info(f"Arm analysis completed. Processed {len(symmetry_scores)} frames, pose detected in {pose_detected_frames} frames")

    if not symmetry_scores:
        return JSONResponse(content={
            "stroke_detected": False, 
            "symmetry_percentage": 0,
            "message": "No pose detected during test."
        })

    # Enhanced analysis
    if len(symmetry_scores) > 10:
        # Remove outliers
        sorted_scores = sorted(symmetry_scores)
        trim_count = len(sorted_scores) // 10
        if trim_count > 0:
            symmetry_scores = sorted_scores[trim_count:-trim_count]

    avg_symmetry = float(np.mean(symmetry_scores))
    symmetry_percentage = avg_symmetry * 100
    std_symmetry = float(np.std(symmetry_scores))
    median_symmetry = float(np.median(symmetry_scores))
    
    # More conservative threshold
    base_threshold = 70.0  # Raised threshold for better detection
    stroke_detected = symmetry_percentage < base_threshold
    
    logger.info(f"Arm Analysis Results:")
    logger.info(f"  - Average Symmetry: {symmetry_percentage:.1f}%")
    logger.info(f"  - Median Symmetry: {median_symmetry * 100:.1f}%")
    logger.info(f"  - Std Deviation: {std_symmetry * 100:.1f}%")
    logger.info(f"  - Stroke Detected: {stroke_detected}")

    return JSONResponse(content={
        "stroke_detected": stroke_detected, 
        "symmetry_percentage": symmetry_percentage,
        "median_symmetry": median_symmetry * 100,
        "frames_processed": len(symmetry_scores),
        "pose_detected_frames": pose_detected_frames,
        "symmetry_variability": std_symmetry * 100,
        "threshold_used": base_threshold
    })
@app.post("/analyze-speech/")
async def analyze_speech_endpoint(file: UploadFile = File(...)):
    """Speech analysis endpoint"""
    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    try:
        with open(file_path, "wb") as f:
            shutil.copyfileobj(file.file, f)
        result = analyze_speech(file_path)
        return JSONResponse(content=result)
    finally:
        if os.path.exists(file_path):
            os.remove(file_path)

# Alternative endpoint that takes boolean results directly
@app.post("/detect-stroke/")
async def detect_stroke_simple(
    face_stroke_detected: str = Form("false"),
    arm_stroke_detected: str = Form("false"),
    speech_stroke_detected: str = Form("false"),
    emergency_contacts: List[str] = Form(default=[])
):
    """Enhanced stroke detection endpoint with proper boolean handling"""
    
    # Convert string values to boolean safely
    try:
        face_bool = face_stroke_detected.lower().strip() == "true"
        arm_bool = arm_stroke_detected.lower().strip() == "true"
        speech_bool = speech_stroke_detected.lower().strip() == "true"
    except:
        face_bool = arm_bool = speech_bool = False
    
    # Log the received values for debugging
    logger.info(f"Received stroke detection results:")
    logger.info(f"Face: {face_stroke_detected} -> {face_bool}")
    logger.info(f"Arm: {arm_stroke_detected} -> {arm_bool}")
    logger.info(f"Speech: {speech_stroke_detected} -> {speech_bool}")
    logger.info(f"Emergency contacts: {emergency_contacts}")
    
    # Determine overall stroke detection
    stroke_detected = face_bool or arm_bool or speech_bool
    positive_tests = sum([face_bool, arm_bool, speech_bool])
    combined_score = positive_tests / 3.0
    
    # Create detailed results
    result = {
        "stroke_detected": stroke_detected,
        "face_positive": face_bool,
        "arm_positive": arm_bool,
        "speech_positive": speech_bool,
        "positive_tests": positive_tests,
        "combined_score": combined_score,
        "analysis_summary": {
            "face_test": "POSITIVE" if face_bool else "NEGATIVE",
            "arm_test": "POSITIVE" if arm_bool else "NEGATIVE", 
            "speech_test": "POSITIVE" if speech_bool else "NEGATIVE"
        }
    }
    
    # Send emergency notifications if stroke detected
    if stroke_detected and emergency_contacts:
        alert_message = (
            f"🚨 STROKE ALERT: Potential stroke symptoms detected!\n\n"
            f"Test Results:\n"
            f"• Face Symmetry: {'ASYMMETRICAL' if face_bool else 'NORMAL'}\n"
            f"• Arm Movement: {'IMPAIRED' if arm_bool else 'NORMAL'}\n"
            f"• Speech: {'IMPAIRED' if speech_bool else 'NORMAL'}\n\n"
            f"Positive Tests: {positive_tests}/3\n\n"
            f"⚠️ SEEK IMMEDIATE MEDICAL ATTENTION ⚠️\n"
            f"Call 911 or go to nearest emergency room!"
        )
        
        successful_notifications = 0
        failed_notifications = []
        
        for contact in emergency_contacts:
            try:
                if contact.strip():  # Only send to non-empty contacts
                    sms_result = send_sms(contact.strip(), alert_message)
                    if sms_result:
                        successful_notifications += 1
                        logger.info(f"Emergency alert sent successfully to {contact}")
                    else:
                        failed_notifications.append(contact)
                        logger.warning(f"Failed to send alert to {contact}")
            except Exception as e:
                failed_notifications.append(contact)
                logger.error(f"Exception sending SMS to {contact}: {e}")
        
        result.update({
            "notifications_sent": successful_notifications,
            "total_contacts": len([c for c in emergency_contacts if c.strip()]),
            "failed_contacts": len(failed_notifications),
            "alert_message": alert_message
        })
        
        logger.info(f"Emergency notifications: {successful_notifications} sent, {len(failed_notifications)} failed")
    
    # Log final result
    logger.info(f"Final stroke detection result: {result}")
    
    return JSONResponse(content=result)
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return JSONResponse(content={"status": "healthy", "timestamp": time.time()})

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return JSONResponse(content={
        "message": "Enhanced Stroke Detection API",
        "version": "2.0",
        "endpoints": [
            "/analyze-face/",
            "/analyze-arm/",
            "/analyze-speech/",
            "/detect-stroke/",
            "/health"
        ]
    })

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")