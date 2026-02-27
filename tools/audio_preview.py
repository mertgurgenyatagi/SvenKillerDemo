import os
import csv
import math
import threading
import tkinter as tk
from tkinter import ttk, messagebox

# Try to import pygame for audio playback
try:
    import pygame
except Exception as e:
    pygame = None


def find_repo_root(start_path: str) -> str:
    cur = os.path.abspath(start_path)
    while True:
        if os.path.exists(os.path.join(cur, 'project.godot')) or os.path.exists(os.path.join(cur, 'CLAUDE.md')):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return os.path.abspath(start_path)
        cur = parent


def db_to_linear(db: float) -> float:
    # Convert dB to linear amplitude (20*log10) inverse
    return 10 ** (db / 20.0)


class AudioEntry:
    def __init__(self, row, repo_root):
        self.file_path = row.get('file_path', '').strip()
        self.configured_in = row.get('configured_in', '').strip()
        self.orig_db_raw = row.get('configured_volume_db', '').strip()
        try:
            self.orig_db = float(self.orig_db_raw) if self.orig_db_raw != '' else 0.0
        except:
            self.orig_db = 0.0
        self.spatial = row.get('spatial', '').strip().lower() == 'true'
        self.bus = row.get('bus', '').strip()
        self.code_override_file = row.get('code_override_file', '').strip()
        self.code_volume_db_raw = row.get('code_volume_db', '').strip()
        try:
            self.code_volume_db = float(self.code_volume_db_raw) if self.code_volume_db_raw != '' else None
        except:
            self.code_volume_db = None
        self.notes = row.get('notes', '').strip()

        self.repo_root = repo_root
        self.abs_path = os.path.normpath(os.path.join(repo_root, self.file_path))
        self.exists = os.path.exists(self.abs_path)

        # Current dB shown in UI (start with code override if present else configured)
        if self.code_volume_db is not None:
            self.current_db = self.code_volume_db
        else:
            self.current_db = self.orig_db

        # pygame Sound placeholder
        self.sound = None
        self.channel = None

    def load_sound(self):
        if not pygame:
            return False
        if not self.exists:
            return False
        try:
            # pygame can take a file path
            self.sound = pygame.mixer.Sound(self.abs_path)
            return True
        except Exception:
            self.sound = None
            return False

    def play(self):
        if not pygame or not self.sound:
            return
        linear = db_to_linear(self.current_db)
        # Clamp linear to [0.0, 1.0] for pygame set_volume
        linear_clamped = max(0.0, min(1.0, linear))
        self.sound.set_volume(linear_clamped)
        self.channel = self.sound.play()

    def stop(self):
        try:
            if self.channel:
                self.channel.stop()
        except Exception:
            pass

    def set_db(self, db_val: float):
        self.current_db = db_val

    def reset_db(self):
        if self.code_volume_db is not None:
            self.current_db = self.code_volume_db
        else:
            self.current_db = self.orig_db


class AudioPreviewApp:
    def __init__(self, master):
        self.master = master
        master.title('OGG Volume Preview')

        script_dir = os.path.dirname(os.path.abspath(__file__))
        repo_root = find_repo_root(script_dir)
        self.repo_root = repo_root

        csv_path = os.path.join(repo_root, 'resources', 'ogg_volume_map.csv')
        if not os.path.exists(csv_path):
            messagebox.showerror('Missing CSV', f'CSV not found at {csv_path}')
            master.destroy()
            return

        self.entries = []
        with open(csv_path, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                e = AudioEntry(row, repo_root)
                self.entries.append(e)

        # Init pygame mixer if available
        if pygame:
            try:
                pygame.mixer.init()
            except Exception as e:
                messagebox.showwarning('Pygame init failed', f'pygame.mixer.init() failed: {e}')

        # Preload sounds in background thread to avoid UI freeze
        threading.Thread(target=self._preload_sounds, daemon=True).start()

        # Build UI
        self._build_ui()

    def _preload_sounds(self):
        if not pygame:
            return
        for e in self.entries:
            if e.exists:
                e.load_sound()

    def _build_ui(self):
        frm = ttk.Frame(self.master)
        frm.pack(fill='both', expand=True)

        canvas = tk.Canvas(frm)
        scrollbar = ttk.Scrollbar(frm, orient='vertical', command=canvas.yview)
        self.list_frame = ttk.Frame(canvas)

        self.list_frame.bind(
            '<Configure>', lambda e: canvas.configure(scrollregion=canvas.bbox('all'))
        )

        canvas.create_window((0, 0), window=self.list_frame, anchor='nw')
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side='left', fill='both', expand=True)
        scrollbar.pack(side='right', fill='y')

        # Populate rows
        for idx, entry in enumerate(self.entries):
            self._add_row(idx, entry)

        # Close handler to stop sounds
        self.master.protocol('WM_DELETE_WINDOW', self._on_close)

    def _add_row(self, idx, entry: AudioEntry):
        row = ttk.Frame(self.list_frame, padding=(6, 6))
        row.grid(column=0, row=idx, sticky='ew')
        row.columnconfigure(1, weight=1)

        label = ttk.Label(row, text=entry.file_path)
        label.grid(column=0, row=0, sticky='w')

        db_var = tk.DoubleVar(value=entry.current_db)

        db_label = ttk.Label(row, text=f'{entry.current_db:.1f} dB')
        db_label.grid(column=1, row=0, sticky='e')

        play_btn = ttk.Button(row, text='Play', command=lambda e=entry, v=db_var, l=db_label: self._play_entry(e, v, l))
        play_btn.grid(column=2, row=0, padx=6)

        stop_btn = ttk.Button(row, text='Stop', command=lambda e=entry: e.stop())
        stop_btn.grid(column=3, row=0, padx=6)

        slider = ttk.Scale(row, from_=24.0, to=-80.0, orient='horizontal', command=lambda val, e=entry, v=db_var, l=db_label: self._on_slider(val, e, v, l))
        slider.set(entry.current_db)
        slider.grid(column=0, row=1, columnspan=4, sticky='ew', pady=(4, 0))

        reset_btn = ttk.Button(row, text='Reset', command=lambda e=entry, s=slider, v=db_var, l=db_label: self._reset_entry(e, s, v, l))
        reset_btn.grid(column=4, row=0, padx=6)

        # Notes tooltip as small label
        notes = entry.notes
        if notes:
            notes_label = ttk.Label(row, text=notes, foreground='gray')
            notes_label.grid(column=0, row=2, columnspan=5, sticky='w')

    def _play_entry(self, entry: AudioEntry, db_var: tk.DoubleVar, db_label: ttk.Label):
        # Stop all others
        for e in self.entries:
            try:
                e.stop()
            except:
                pass
        # Update entry current_db from var
        entry.current_db = float(db_var.get())
        if not pygame or not entry.sound:
            # Try to load on demand
            if not pygame:
                messagebox.showerror('Playback unavailable', 'pygame is not installed. Install pygame to enable playback.')
                return
            if not entry.exists:
                messagebox.showerror('File missing', f'File not found: {entry.abs_path}')
                return
            loaded = entry.load_sound()
            if not loaded:
                messagebox.showerror('Load failed', f'Failed to load: {entry.abs_path}')
                return
        entry.play()
        db_label.config(text=f'{entry.current_db:.1f} dB')

    def _on_slider(self, val, entry: AudioEntry, db_var: tk.DoubleVar, db_label: ttk.Label):
        try:
            db = float(val)
        except:
            db = 0.0
        db_var.set(db)
        entry.set_db(db)
        db_label.config(text=f'{db:.1f} dB')

    def _reset_entry(self, entry: AudioEntry, slider: ttk.Scale, db_var: tk.DoubleVar, db_label: ttk.Label):
        entry.reset_db()
        slider.set(entry.current_db)
        db_var.set(entry.current_db)
        db_label.config(text=f'{entry.current_db:.1f} dB')

    def _on_close(self):
        for e in self.entries:
            try:
                e.stop()
            except:
                pass
        try:
            if pygame:
                pygame.mixer.quit()
        except:
            pass
        self.master.destroy()


if __name__ == '__main__':
    root = tk.Tk()
    app = AudioPreviewApp(root)
    root.mainloop()
