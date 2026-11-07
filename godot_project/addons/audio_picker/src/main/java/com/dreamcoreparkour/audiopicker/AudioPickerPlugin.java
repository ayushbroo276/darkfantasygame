package com.dreamcoreparkour.audiopicker;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

public final class AudioPickerPlugin extends GodotPlugin {
	private static final String TAG = "AudioPicker";
	private static final int REQUEST_CODE = 7401;
	private static final long MAX_TRACK_BYTES = 128L * 1024L * 1024L;

	public AudioPickerPlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "AudioPicker";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		return new HashSet<>(Arrays.asList(
				new SignalInfo("audio_selected", String.class, String.class),
				new SignalInfo("audio_picker_cancelled"),
				new SignalInfo("audio_picker_error", String.class)));
	}

	@UsedByGodot
	public void openAudioPicker() {
		runOnHostThread(() -> {
			Activity activity = getActivity();
			if (activity == null) {
				emitSignal("audio_picker_error", "The Android file picker is unavailable.");
				return;
			}

			Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
			intent.addCategory(Intent.CATEGORY_OPENABLE);
			intent.setType("audio/*");
			try {
				activity.startActivityForResult(intent, REQUEST_CODE);
			} catch (ActivityNotFoundException exception) {
				Log.e(TAG, "No Android document picker is installed.", exception);
				emitSignal("audio_picker_error", "No Android file picker is available.");
			}
		});
	}

	@Override
	public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
		if (requestCode != REQUEST_CODE) {
			return;
		}
		if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
			emitSignal("audio_picker_cancelled");
			return;
		}

		Uri uri = data.getData();
		Activity activity = getActivity();
		if (activity == null) {
			emitSignal("audio_picker_error", "Could not access the selected song.");
			return;
		}

		Thread importThread = new Thread(() -> importAudio(activity, uri), "AudioPickerImport");
		importThread.start();
	}

	private void importAudio(Activity activity, Uri uri) {
		File temporaryFile = null;
		try {
			String displayName = getDisplayName(activity, uri);
			String extension = supportedExtension(displayName, activity.getContentResolver().getType(uri));
			if (extension.isEmpty()) {
				emitSignal("audio_picker_error", "Choose an MP3, OGG, or WAV audio file.");
				return;
			}

			File musicDirectory = new File(activity.getFilesDir(), "music_imports");
			if (!musicDirectory.isDirectory() && !musicDirectory.mkdirs()) {
				throw new IllegalStateException("Could not create the music library.");
			}

			temporaryFile = File.createTempFile("track-", ".tmp", musicDirectory);
			File destination = new File(musicDirectory, temporaryFile.getName().replace(".tmp", "." + extension));
			long copiedBytes = 0L;
			try (InputStream input = activity.getContentResolver().openInputStream(uri);
					FileOutputStream output = new FileOutputStream(temporaryFile)) {
				if (input == null) {
					throw new IllegalStateException("Could not read the selected audio file.");
				}
				byte[] buffer = new byte[16384];
				int count;
				while ((count = input.read(buffer)) != -1) {
					copiedBytes += count;
					if (copiedBytes > MAX_TRACK_BYTES) {
						throw new IllegalArgumentException("The selected song is larger than 128 MB.");
					}
					output.write(buffer, 0, count);
				}
			}

			if (copiedBytes == 0L) {
				throw new IllegalArgumentException("The selected audio file is empty.");
			}
			if (!temporaryFile.renameTo(destination)) {
				throw new IllegalStateException("Could not save the selected song.");
			}
			temporaryFile = null;
			emitSignal("audio_selected", destination.getAbsolutePath(), displayName);
		} catch (Exception exception) {
			Log.e(TAG, "Could not import the selected audio file.", exception);
			emitSignal("audio_picker_error", exception.getMessage() == null
					? "Could not import the selected song."
					: exception.getMessage());
		} finally {
			if (temporaryFile != null && temporaryFile.exists() && !temporaryFile.delete()) {
				Log.w(TAG, "Could not remove a partial imported audio file.");
			}
		}
	}

	private String getDisplayName(Activity activity, Uri uri) {
		try (Cursor cursor = activity.getContentResolver().query(
				uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
			if (cursor != null && cursor.moveToFirst()) {
				int nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
				if (nameColumn >= 0) {
					String name = cursor.getString(nameColumn);
					if (name != null && !name.trim().isEmpty()) {
						return name;
					}
				}
			}
		} catch (Exception exception) {
			Log.w(TAG, "Could not read the selected song's display name.", exception);
		}
		return "Imported song";
	}

	private String supportedExtension(String displayName, String mimeType) {
		String lowercaseName = displayName.toLowerCase(Locale.ROOT);
		if (lowercaseName.endsWith(".mp3")) {
			return "mp3";
		}
		if (lowercaseName.endsWith(".ogg")) {
			return "ogg";
		}
		if (lowercaseName.endsWith(".wav")) {
			return "wav";
		}
		if ("audio/mpeg".equals(mimeType)) {
			return "mp3";
		}
		if ("audio/ogg".equals(mimeType) || "application/ogg".equals(mimeType)) {
			return "ogg";
		}
		if ("audio/wav".equals(mimeType) || "audio/x-wav".equals(mimeType)) {
			return "wav";
		}
		return "";
	}
}
