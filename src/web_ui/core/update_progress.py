import threading
import time

class UpdateProgress:
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
                cls._instance.status = 'idle'
                cls._instance.message = ''
                cls._instance.current_file = ''
                cls._instance.progress = 0
                cls._instance.total_files = 0
                cls._instance.error = None
            return cls._instance
    
    def start_update(self, total_files=0):
        self.status = 'starting'
        self.message = 'Creating backup...'
        self.progress = 0
        self.total_files = total_files
        self.error = None
    
    def update_progress(self, message, file='', progress=0, total=0):
        self.message = message
        self.current_file = file
        self.progress = progress
        self.total_files = total
    
    def set_error(self, error):
        self.status = 'error'
        self.error = error
    
    def complete(self):
        self.status = 'complete'
        self.message = 'Update completed'
    
    def reset(self):
        self.status = 'idle'
        self.message = ''
        self.current_file = ''
        self.progress = 0
        self.total_files = 0
        self.error = None
    
    def get_status(self):
        return {
            'status': self.status,
            'message': self.message,
            'current_file': self.current_file,
            'progress': self.progress,
            'total_files': self.total_files,
            'error': self.error
        }