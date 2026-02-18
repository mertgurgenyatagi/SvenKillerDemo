#!/usr/bin/env python3
"""
Simple Audio Configuration Editor for Godot AudioManager
Allows previewing and editing audio_config.tres entries
"""

import tkinter as tk
from tkinter import ttk, messagebox
import pygame
import os
import re
from pathlib import Path

class AudioConfigEditor:
    def __init__(self, root):
        self.root = root
        self.root.title("Sven Killer - Audio Configuration Editor")
        self.root.geometry("900x700")

        # Initialize pygame mixer for audio playback
        pygame.mixer.init()

        # Data
        self.project_root = Path(__file__).parent.parent.parent
        self.config_path = self.project_root / "resources" / "audio_config.tres"
        self.entries = []
        self.current_sound = None

        # Create UI
        self.create_ui()

        # Load config
        self.load_config()

    def create_ui(self):
        # Top frame - Info
        info_frame = tk.Frame(self.root, bg="#2b2b2b", padx=10, pady=10)
        info_frame.pack(fill=tk.X)

        tk.Label(
            info_frame,
            text="Audio Configuration Editor",
            font=("Arial", 16, "bold"),
            bg="#2b2b2b",
            fg="white"
        ).pack()

        tk.Label(
            info_frame,
            text=f"Config: {self.config_path}",
            font=("Arial", 9),
            bg="#2b2b2b",
            fg="#888888"
        ).pack()

        # Main content frame
        content_frame = tk.Frame(self.root)
        content_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # Left panel - Audio list
        list_frame = tk.LabelFrame(content_frame, text="Audio Entries", padx=5, pady=5)
        list_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # Scrollbar for list
        scrollbar = tk.Scrollbar(list_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Listbox
        self.audio_listbox = tk.Listbox(
            list_frame,
            font=("Consolas", 10),
            yscrollcommand=scrollbar.set,
            selectmode=tk.SINGLE
        )
        self.audio_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.audio_listbox.yview)

        self.audio_listbox.bind('<<ListboxSelect>>', self.on_audio_select)

        # Right panel - Details & Controls
        details_frame = tk.LabelFrame(content_frame, text="Audio Details", padx=10, pady=10)
        details_frame.pack(side=tk.RIGHT, fill=tk.BOTH, padx=(10, 0))

        # Entry details
        self.detail_labels = {}

        fields = [
            ("ID", "id"),
            ("Name", "name"),
            ("Path", "path"),
            ("Volume (dB)", "volume_db"),
            ("Bus", "bus"),
            ("Pitch Scale", "pitch_scale"),
            ("Max Distance", "max_distance"),
            ("Spatial", "spatial"),
            ("Preload", "preload_on_startup")
        ]

        for i, (label, key) in enumerate(fields):
            tk.Label(details_frame, text=label + ":", anchor="w", width=15).grid(row=i, column=0, sticky="w", pady=2)
            value_label = tk.Label(details_frame, text="-", anchor="w", font=("Consolas", 9), fg="#0066cc")
            value_label.grid(row=i, column=1, sticky="w", pady=2)
            self.detail_labels[key] = value_label

        # Playback controls
        control_frame = tk.Frame(details_frame)
        control_frame.grid(row=len(fields), column=0, columnspan=2, pady=20)

        self.play_button = tk.Button(
            control_frame,
            text="▶ Play",
            command=self.play_audio,
            width=15,
            height=2,
            bg="#4CAF50",
            fg="white",
            font=("Arial", 12, "bold"),
            state=tk.DISABLED
        )
        self.play_button.pack(pady=5)

        self.stop_button = tk.Button(
            control_frame,
            text="■ Stop",
            command=self.stop_audio,
            width=15,
            bg="#f44336",
            fg="white",
            font=("Arial", 10),
            state=tk.DISABLED
        )
        self.stop_button.pack(pady=5)

        # Volume slider
        tk.Label(control_frame, text="Preview Volume:", font=("Arial", 9)).pack(pady=(10, 0))
        self.volume_slider = tk.Scale(
            control_frame,
            from_=0,
            to=100,
            orient=tk.HORIZONTAL,
            command=self.on_volume_change,
            length=200
        )
        self.volume_slider.set(50)
        self.volume_slider.pack()

        # Status bar
        self.status_label = tk.Label(
            self.root,
            text="Ready",
            anchor="w",
            bg="#2b2b2b",
            fg="white",
            padx=10,
            pady=5
        )
        self.status_label.pack(fill=tk.X, side=tk.BOTTOM)

    def load_config(self):
        """Parse audio_config.tres and extract entries"""
        if not self.config_path.exists():
            messagebox.showerror("Error", f"Config file not found:\n{self.config_path}")
            return

        try:
            with open(self.config_path, 'r') as f:
                content = f.read()

            # Parse SubResources - split by [sub_resource markers
            subresource_sections = re.split(r'\[sub_resource type="Resource" id="', content)[1:]  # Skip first empty split

            subresource_map = {}
            for section in subresource_sections:
                # Extract resource ID (first line before closing quote)
                id_match = re.match(r'([^"]+)"\]', section)
                if not id_match:
                    continue

                res_id = id_match.group(1)
                # Get content until next [sub_resource or [resource marker
                content_match = re.search(r'\](.*?)(?=\[(?:sub_resource|resource)|$)', section, re.DOTALL)
                if content_match:
                    res_content = content_match.group(1)
                    entry = self.parse_entry(res_content)
                    subresource_map[res_id] = entry

            # Parse main resource entries mapping
            entries_match = re.search(r'entries = \{([^}]+)\}', content, re.DOTALL)
            if entries_match:
                entries_str = entries_match.group(1)
                entry_pairs = re.findall(r'(\d+): SubResource\("([^"]+)"\)', entries_str)

                for entry_id, res_id in sorted(entry_pairs, key=lambda x: int(x[0])):
                    if res_id in subresource_map:
                        entry = subresource_map[res_id]
                        entry['id'] = int(entry_id)
                        self.entries.append(entry)

            # Populate listbox
            for entry in self.entries:
                display_text = f"{entry['id']:2d}  {entry.get('name', 'UNNAMED'):25s}  [{entry.get('bus', 'Master')}]"
                self.audio_listbox.insert(tk.END, display_text)

            self.status_label.config(text=f"Loaded {len(self.entries)} audio entries")

        except Exception as e:
            messagebox.showerror("Error", f"Failed to parse config:\n{e}")
            self.status_label.config(text="Error loading config")

    def parse_entry(self, content):
        """Parse a single AudioEntry SubResource"""
        entry = {
            'name': '',
            'path': '',
            'volume_db': 0.0,
            'max_distance': 20.0,
            'bus': 'Master',
            'pitch_scale': 1.0,
            'preload_on_startup': False,
            'spatial': False
        }

        # Extract fields
        name_match = re.search(r'name = "([^"]*)"', content)
        if name_match:
            entry['name'] = name_match.group(1)

        path_match = re.search(r'path = "([^"]*)"', content)
        if path_match:
            entry['path'] = path_match.group(1)

        volume_match = re.search(r'volume_db = ([\d.-]+)', content)
        if volume_match:
            entry['volume_db'] = float(volume_match.group(1))

        distance_match = re.search(r'max_distance = ([\d.]+)', content)
        if distance_match:
            entry['max_distance'] = float(distance_match.group(1))

        bus_match = re.search(r'bus = "([^"]*)"', content)
        if bus_match:
            entry['bus'] = bus_match.group(1)

        pitch_match = re.search(r'pitch_scale = ([\d.]+)', content)
        if pitch_match:
            entry['pitch_scale'] = float(pitch_match.group(1))

        entry['spatial'] = 'spatial = true' in content
        entry['preload_on_startup'] = 'preload_on_startup = true' in content

        return entry

    def on_audio_select(self, event):
        """Handle audio entry selection"""
        selection = self.audio_listbox.curselection()
        if not selection:
            return

        index = selection[0]
        entry = self.entries[index]

        # Update detail labels
        self.detail_labels['id'].config(text=str(entry['id']))
        self.detail_labels['name'].config(text=entry['name'])
        self.detail_labels['path'].config(text=entry['path'].replace('res://', ''))
        self.detail_labels['volume_db'].config(text=f"{entry['volume_db']:.1f} dB")
        self.detail_labels['bus'].config(text=entry['bus'])
        self.detail_labels['pitch_scale'].config(text=f"{entry['pitch_scale']:.1f}")
        self.detail_labels['max_distance'].config(text=f"{entry['max_distance']:.1f}m" if entry['spatial'] else "N/A")
        self.detail_labels['spatial'].config(text="Yes" if entry['spatial'] else "No")
        self.detail_labels['preload_on_startup'].config(text="Yes" if entry['preload_on_startup'] else "No")

        # Enable play button if file exists
        audio_path = self.project_root / entry['path'].replace('res://', '')
        if audio_path.exists():
            self.play_button.config(state=tk.NORMAL)
            self.status_label.config(text=f"Ready to play: {entry['name']}")
        else:
            self.play_button.config(state=tk.DISABLED)
            self.status_label.config(text=f"Audio file not found: {audio_path}")

    def play_audio(self):
        """Play selected audio file"""
        selection = self.audio_listbox.curselection()
        if not selection:
            return

        index = selection[0]
        entry = self.entries[index]

        audio_path = self.project_root / entry['path'].replace('res://', '')
        if not audio_path.exists():
            messagebox.showerror("Error", f"Audio file not found:\n{audio_path}")
            return

        try:
            # Stop current sound if playing
            if self.current_sound:
                pygame.mixer.music.stop()

            # Load and play
            pygame.mixer.music.load(str(audio_path))
            pygame.mixer.music.set_volume(self.volume_slider.get() / 100.0)
            pygame.mixer.music.play()

            self.stop_button.config(state=tk.NORMAL)
            self.status_label.config(text=f"Playing: {entry['name']}")

        except Exception as e:
            messagebox.showerror("Error", f"Failed to play audio:\n{e}")

    def stop_audio(self):
        """Stop audio playback"""
        pygame.mixer.music.stop()
        self.stop_button.config(state=tk.DISABLED)
        self.status_label.config(text="Stopped")

    def on_volume_change(self, value):
        """Handle volume slider change"""
        if pygame.mixer.music.get_busy():
            pygame.mixer.music.set_volume(int(value) / 100.0)

def main():
    root = tk.Tk()
    app = AudioConfigEditor(root)
    root.mainloop()

if __name__ == "__main__":
    main()
