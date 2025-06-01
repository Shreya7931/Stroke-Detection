from fastapi import FastAPI, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import cv2
import mediapipe as mp
import os
import shutil
import numpy as np
from twilio.rest import Client
import os
from fastapi import Form
from typing import List


TWILIO_SID = os.getenv('TWILIO_SID')
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN')
TWILIO_PHONE = os.getenv('TWILIO_PHONE')

twilio_client = Client(TWILIO_SID, TWILIO_AUTH_TOKEN)

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# MediaPipe initialization
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(static_image_mode=False, max_num_faces=1)

mp_pose = mp.solutions.pose
pose = mp_pose.Pose()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def calculate_face_symmetry(frame):
    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = face_mesh.process(img_rgb)

    if not results.multi_face_landmarks:
        return None

    landmarks = results.multi_face_landmarks[0].landmark
    img_h, img_w, _ = frame.shape

    symmetrical_pairs = [
        (234, 454), (130, 359), (55, 285), (159, 386), (145, 374)
    ]

    diffs = []
    for left_idx, right_idx in symmetrical_pairs:
        left_point = landmarks[left_idx]
        right_point = landmarks[right_idx]

        left_x = left_point.x * img_w
        right_x = right_point.x * img_w
        left_y = left_point.y * img_h
        right_y = right_point.y * img_h

        nose = landmarks[9]
        nose_x = nose.x * img_w

        left_dist = abs(left_x - nose_x)
        right_dist = abs(right_x - nose_x)

        diff = abs(left_dist - right_dist)
        diffs.append(diff)

    face_width = abs((landmarks[234].x - landmarks[454].x) * img_w) + 1e-6
    avg_diff = np.mean(diffs)
    symmetry_score = 1 - (avg_diff / face_width)

    return symmetry_score

def analyze_face_symmetry(video_path: str):
    cap = cv2.VideoCapture(video_path)
    symmetry_scores = []
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        score = calculate_face_symmetry(frame)
        if score is not None:
            symmetry_scores.append(score)
    cap.release()

    if not symmetry_scores:
        return {"stroke_detected": False, "stroke_ratio": 0.0, "message": "No face detected in video."}

    avg_symmetry = float(np.mean(symmetry_scores))
    stroke_detected = avg_symmetry < 0.85
    stroke_ratio = 1 - avg_symmetry
    return {"stroke_detected": stroke_detected, "stroke_ratio": stroke_ratio}

def analyze_arm_symmetry(video_path: str):
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
            left_wrist = landmarks[mp_pose.PoseLandmark.LEFT_WRIST]
            right_wrist = landmarks[mp_pose.PoseLandmark.RIGHT_WRIST]
            if abs(left_wrist.x - right_wrist.x) < 0.1:
                symmetrical_frames += 1
            total_frames += 1

    cap.release()
    symmetry_percentage = (symmetrical_frames / total_frames) * 100 if total_frames > 0 else 0
    stroke_detected = symmetry_percentage < 70
    return {"stroke_detected": stroke_detected, "symmetry_percentage": symmetry_percentage}

def analyze_speech(audio_path: str):
    return {"stroke_detected": False, "confidence": 0.0}
def send_sms(to_number: str, message: str):
    message = twilio_client.messages.create(
        body=message,
        from_=TWILIO_PHONE,
        to=to_number
    )
    return message.sid

@app.post("/analyze-face/")
async def analyze_face(file: UploadFile = File(...)):
    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    result = analyze_face_symmetry(file_path)
    os.remove(file_path)
    return JSONResponse(content=result)

@app.post("/analyze-arm/")
async def analyze_arm_live():
    import cv2
    import mediapipe as mp
    import numpy as np
    import time

    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose()
    mp_drawing = mp.solutions.drawing_utils

    cap = cv2.VideoCapture(0)
    frame_width = int(cap.get(3))
    frame_height = int(cap.get(4))
    video_path = os.path.join(UPLOAD_FOLDER, 'arm_symmetry_video.avi')
    out = cv2.VideoWriter(video_path, cv2.VideoWriter_fourcc(*'XVID'), 20, (frame_width, frame_height))

    start_time = time.time()
    duration = 15

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

            left_shoulder = (int(landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER].x * frame.shape[1]),
                             int(landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER].y * frame.shape[0]))
            right_shoulder = (int(landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER].x * frame.shape[1]),
                              int(landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER].y * frame.shape[0]))
            left_wrist = (int(landmarks[mp_pose.PoseLandmark.LEFT_WRIST].x * frame.shape[1]),
                          int(landmarks[mp_pose.PoseLandmark.LEFT_WRIST].y * frame.shape[0]))
            right_wrist = (int(landmarks[mp_pose.PoseLandmark.RIGHT_WRIST].x * frame.shape[1]),
                           int(landmarks[mp_pose.PoseLandmark.RIGHT_WRIST].y * frame.shape[0]))

            mid_x = (left_shoulder[0] + right_shoulder[0]) // 2
            left_wrist_dist = abs(left_wrist[0] - mid_x)
            right_wrist_dist = abs(right_wrist[0] - mid_x)

            threshold = 20  # Pixel tolerance
            if abs(left_wrist_dist - right_wrist_dist) > threshold:
                symmetrical_frames += 1
            total_frames += 1

        out.write(frame)

        if time.time() - start_time > duration:
            break

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    out.release()
    cv2.destroyAllWindows()

    symmetry_percentage = (symmetrical_frames / total_frames) * 100 if total_frames > 0 else 0
    stroke_detected = symmetry_percentage < 70

    return JSONResponse(content={
        "stroke_detected": stroke_detected,
        "symmetry_percentage": symmetry_percentage
    })


@app.post("/analyze-speech/")
async def analyze_speech_endpoint(file: UploadFile = File(...)):
    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    result = analyze_speech(file_path)
    os.remove(file_path)
    return JSONResponse(content=result)

@app.post("/detect-stroke/")
async def detect_stroke(
    face_result: float = Form(...),
    arm_result: float = Form(...),
    speech_result: float = Form(...),
    emergency_contacts: List[str] = Form(...)
):
    combined_score = (face_result * 0.4) + (arm_result * 0.4) + (speech_result * 0.2)
    stroke_detected = combined_score > 0.5
    if stroke_detected:
        alert_message = "ALERT: Stroke detected! Immediate attention required."
        for contact in emergency_contacts:
            try:
                send_sms(contact, alert_message)
            except Exception as e:
                print(f"Failed to send SMS to {contact}: {e}")
    return JSONResponse(content={"stroke_detected": stroke_detected})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
