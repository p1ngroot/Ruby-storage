from flask import Flask, render_template, request, jsonify, send_file, session, redirect, url_for, send_from_directory
from werkzeug.utils import secure_filename
import os
import shutil
import hashlib
from datetime import datetime
from functools import wraps

app = Flask(__name__)
app.secret_key = 'ruby_secret_key_change_in_production'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024 * 1024  # 16GB max

# Создаем папки если не существуют
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs('static', exist_ok=True)

# Учетные данные
USERNAME = 'root'
PASSWORD_HASH = hashlib.sha256('DIMAzay4214'.encode()).hexdigest()  # Измени 'DIMAzay4214' на свой пароль

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        if username == USERNAME and password_hash == PASSWORD_HASH:
            session['logged_in'] = True
            return redirect(url_for('index'))
        return render_template('login.html', error='Неверный логин или пароль')
    
    if 'logged_in' in session:
        return redirect(url_for('index'))
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    return render_template('index.html')

@app.route('/api/files', methods=['GET'])
@login_required
def get_files():
    path = request.args.get('path', '')
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    
    if not os.path.exists(full_path):
        return jsonify({'error': 'Path not found'}), 404
    
    items = []
    for item in os.listdir(full_path):
        item_path = os.path.join(full_path, item)
        relative_path = os.path.join(path, item)
        
        stat = os.stat(item_path)
        items.append({
            'name': item,
            'path': relative_path,
            'is_dir': os.path.isdir(item_path),
            'size': stat.st_size if not os.path.isdir(item_path) else 0,
            'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({'items': sorted(items, key=lambda x: (not x['is_dir'], x['name']))})

@app.route('/api/upload', methods=['POST'])
@login_required
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file'}), 400
    
    file = request.files['file']
    path = request.form.get('path', '')
    
    if file.filename == '':
        return jsonify({'error': 'No filename'}), 400
    
    filename = secure_filename(file.filename)
    upload_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    os.makedirs(upload_path, exist_ok=True)
    
    file.save(os.path.join(upload_path, filename))
    return jsonify({'success': True})

@app.route('/api/create_folder', methods=['POST'])
@login_required
def create_folder():
    data = request.json
    path = data.get('path', '')
    folder_name = secure_filename(data.get('name', ''))
    
    if not folder_name:
        return jsonify({'error': 'Invalid folder name'}), 400
    
    folder_path = os.path.join(app.config['UPLOAD_FOLDER'], path, folder_name)
    os.makedirs(folder_path, exist_ok=True)
    
    return jsonify({'success': True})

@app.route('/api/delete', methods=['POST'])
@login_required
def delete_item():
    data = request.json
    path = data.get('path', '')
    
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    
    if not os.path.exists(full_path):
        return jsonify({'error': 'Not found'}), 404
    
    if os.path.isdir(full_path):
        shutil.rmtree(full_path)
    else:
        os.remove(full_path)
    
    return jsonify({'success': True})

@app.route('/api/download/<path:filepath>')
@login_required
def download_file(filepath):
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], filepath)
    
    if not os.path.exists(full_path) or os.path.isdir(full_path):
        return jsonify({'error': 'File not found'}), 404
    
    return send_file(full_path, as_attachment=True)

@app.route('/api/storage_info')
@login_required
def storage_info():
    total, used, free = shutil.disk_usage('/')
    
    upload_size = 0
    for dirpath, dirnames, filenames in os.walk(app.config['UPLOAD_FOLDER']):
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            upload_size += os.path.getsize(filepath)
    
    return jsonify({
        'total': total,
        'used': used,
        'free': free,
        'upload_size': upload_size
    })

@app.route('/favicon.ico')
def favicon():
    return send_from_directory('static', 'favicon.svg', mimetype='image/svg+xml')

@app.route('/static/<path:filename>')
def serve_static(filename):
    return send_from_directory('static', filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
