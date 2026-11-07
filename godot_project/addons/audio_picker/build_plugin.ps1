$ErrorActionPreference = "Stop"

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDirectory = (Resolve-Path (Join-Path $scriptDirectory "..\\..")).Path
$sdkDirectory = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "C:\\android" }
$androidJar = Join-Path $sdkDirectory "platforms\\android-35\\android.jar"
$javaHome = $env:JAVA_HOME
if (-not $javaHome) {
	$javaCommand = Get-Command javac.exe -ErrorAction Stop
	$javaHome = Split-Path -Parent (Split-Path -Parent $javaCommand.Source)
}
$javac = Join-Path $javaHome "bin\\javac.exe"
$jar = Join-Path $javaHome "bin\\jar.exe"
$godotVersion = "4.7.2.stable"
$aarUri = "https://repo.maven.apache.org/maven2/org/godotengine/godot/$godotVersion/godot-$godotVersion.aar"

if (-not (Test-Path $androidJar)) {
	throw "Android API 35 is missing: $androidJar"
}
if (-not (Test-Path $javac) -or -not (Test-Path $jar)) {
	throw "A full JDK is required to build the Android audio picker."
}

$workDirectory = Join-Path $env:TEMP ("dreamcore-audio-picker-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $workDirectory | Out-Null
try {
	$godotAar = Join-Path $workDirectory "godot.aar"
	$godotClasses = Join-Path $workDirectory "godot-classes.jar"
	$classesDirectory = Join-Path $workDirectory "classes"
	$packagedClasses = Join-Path $workDirectory "classes.jar"
	$aarOutput = Join-Path $scriptDirectory "audio_picker.aar"

	if ($env:GODOT_ANDROID_AAR) {
		Copy-Item -LiteralPath $env:GODOT_ANDROID_AAR -Destination $godotAar
	} else {
		& curl.exe -L --fail --show-error --silent $aarUri -o $godotAar
		if ($LASTEXITCODE -ne 0) {
			throw "Could not download the Godot $godotVersion Android library."
		}
	}

	Add-Type -AssemblyName System.IO.Compression.FileSystem
	$godotArchive = [System.IO.Compression.ZipFile]::OpenRead($godotAar)
	try {
		$classEntry = $godotArchive.GetEntry("classes.jar")
		if ($null -eq $classEntry) {
			throw "The Godot Android library does not contain classes.jar."
		}
		$classStream = $classEntry.Open()
		$outputStream = [System.IO.File]::Create($godotClasses)
		try {
			$classStream.CopyTo($outputStream)
		} finally {
			$outputStream.Dispose()
			$classStream.Dispose()
		}
	} finally {
		$godotArchive.Dispose()
	}

	New-Item -ItemType Directory -Path $classesDirectory | Out-Null
	$source = Join-Path $scriptDirectory "src\\main\\java\\com\\dreamcoreparkour\\audiopicker\\AudioPickerPlugin.java"
	$classPath = "$godotClasses;$androidJar"
	& $javac -encoding UTF-8 -source 8 -target 8 -classpath $classPath -d $classesDirectory $source
	if ($LASTEXITCODE -ne 0) {
		throw "Could not compile the Android audio picker plugin."
	}
	& $jar --create --file $packagedClasses -C $classesDirectory .
	if ($LASTEXITCODE -ne 0) {
		throw "Could not package the Android audio picker classes."
	}

	if (Test-Path -LiteralPath $aarOutput) {
		Remove-Item -LiteralPath $aarOutput -Force
	}
	$aarArchive = [System.IO.Compression.ZipFile]::Open($aarOutput, [System.IO.Compression.ZipArchiveMode]::Create)
	try {
		[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
			$aarArchive, (Join-Path $scriptDirectory "AndroidManifest.xml"), "AndroidManifest.xml",
			[System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
		[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
			$aarArchive, $packagedClasses, "classes.jar",
			[System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
	} finally {
		$aarArchive.Dispose()
	}
	Get-Item $aarOutput | Select-Object FullName, Length
} finally {
	Remove-Item -LiteralPath $workDirectory -Recurse
}
