# models.py
def old_model(data):
    return 'safe'

def new_model(data):
    if data.get('value', 0) > 50:
        return 'risk'
    return 'safe'
