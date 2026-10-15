# switch.py
ACTIVE_ENV = 'blue'

def get_active():
    return ACTIVE_ENV

def switch_environment():
    global ACTIVE_ENV
    ACTIVE_ENV = 'green' if ACTIVE_ENV=='blue' else 'blue'
    print(f'Switched to: {ACTIVE_ENV}')

def rollback():
    global ACTIVE_ENV
    ACTIVE_ENV = 'blue'
    print('Rolled back to previous stable (blue)')
