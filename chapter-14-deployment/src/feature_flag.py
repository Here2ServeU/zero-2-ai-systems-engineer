# feature_flag.py
USE_NEW_MODEL = False

def toggle_new_model():
    global USE_NEW_MODEL
    USE_NEW_MODEL = not USE_NEW_MODEL
    state = 'ON' if USE_NEW_MODEL else 'OFF'
    print(f'New model: {state}')

def is_new_model_enabled():
    return USE_NEW_MODEL
