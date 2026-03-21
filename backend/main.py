import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import numpy as np
from fastapi import FastAPI, UploadFile, File, Body
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
import base64
from typing import List

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# Инициализация MediaPipe Face Landmarker
script_dir = os.path.dirname(os.path.abspath(__file__))
model_path = os.path.join(script_dir, "face_landmarker.task")

base_options = python.BaseOptions(model_asset_path=model_path)
options = vision.FaceLandmarkerOptions(
    base_options=base_options,
    output_face_blendshapes=False,
    output_facial_transformation_matrixes=False,
    num_faces=5
)
landmarker = vision.FaceLandmarker.create_from_options(options)

# Инициализация распознавателя лиц OpenCV (LBPH)
recognizer = cv2.face.LBPHFaceRecognizer_create()
label_map = {} # {id: name}
is_trained = False

@app.post("/train")
async def train(data: dict = Body(...)):
    global is_trained, label_map
    faces = []
    labels = []
    label_map = {}
    
    current_label = 0
    for person in data.get("persons", []):
        name = person["name"]
        label_map[current_label] = name
        
        for img_base64 in person.get("images", []):
            try:
                # Декодируем base64
                img_data = base64.b64decode(img_base64)
                nparr = np.frombuffer(img_data, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
                
                if img is not None:
                    # Находим лицо на фото для обучения
                    # Используем простой Haar Cascade для быстроты обучения
                    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
                    detected = face_cascade.detectMultiScale(img, 1.3, 5)
                    for (x, y, w, h) in detected:
                        roi = img[y:y+h, x:x+w]
                        roi = cv2.resize(roi, (200, 200))
                        faces.append(roi)
                        labels.append(current_label)
            except Exception as e:
                print(f"Error training on image for {name}: {e}")
        current_label += 1

    if faces:
        recognizer.train(faces, np.array(labels))
        is_trained = True
        return {"status": "success", "count": len(faces)}
    return {"status": "no_faces_found"}

@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None: return {"detections": []}

    h, w, _ = img.shape
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
    
    result = landmarker.detect(mp_image)
    
    detections = []
    if result.face_landmarks:
        for landmarks in result.face_landmarks:
            # 1. Считаем Bounding Box по всем точкам
            xs = [lm.x for lm in landmarks]
            ys = [lm.y for lm in landmarks]
            xmin, xmax = min(xs), max(xs)
            ymin, ymax = min(ys), max(ys)
            
            # 2. Попытка распознавания, если обучен
            name = "Unknown"
            confidence = 0.0
            if is_trained:
                # Вырезаем лицо (чуть шире для LBPH)
                lx, ly = int(xmin * w), int(ymin * h)
                lw, lh = int((xmax - xmin) * w), int((ymax - ymin) * h)
                
                if lw > 20 and lh > 20:
                    try:
                        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
                        roi = gray[max(0, ly):min(h, ly+lh), max(0, lx):min(w, lx+lw)]
                        roi = cv2.resize(roi, (200, 200))
                        label_id, dist = recognizer.predict(roi)
                        # В LBPH dist < 100 это хорошее совпадение
                        if dist < 80:
                            name = label_map.get(label_id, "Unknown")
                            confidence = 1.0 - (dist / 100.0)
                        else:
                            confidence = 0.3 # Низкая уверенность
                    except: pass

            # 3. Собираем точки контура Face Oval (индексы MediaPipe 10, 338, 297, etc. - Овал это 10-152)
            # В MediaPipe индексы овала лица: 10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 10
            oval_indices = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67]
            oval_points = [{"x": landmarks[idx].x, "y": landmarks[idx].y} for idx in oval_indices]

            detections.append({
                "x": xmin, "y": ymin, "w": xmax - xmin, "h": ymax - ymin,
                "name": name,
                "confidence": confidence,
                "oval": oval_points # Для ровной отрисовки "прям по лицу"
            })
            
    return {"detections": detections}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
