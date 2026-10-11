# ==============================================================================
# سكربت PowerShell لبناء تطبيق «دليلك الطبي» وتحويله إلى APK تلقائياً
# Dalilik Al-Tibbi - Standalone PowerShell APK Builder
# ==============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       بدء عملية بناء ملف APK لتطبيق «دليلك الطبي»         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. التحقق من وجود Java JDK
Write-Host "`n[1/4] فحص بيئة تشغيل Java..." -ForegroundColor Yellow
$javaCmd = Get-Command java -ErrorAction SilentlyContinue

if (-not $javaCmd) {
    if ($env:JAVA_HOME -and (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
        $env:Path = "$env:JAVA_HOME\bin;" + $env:Path
        Write-Host "✓ تم العثور على Java عبر JAVA_HOME" -ForegroundColor Green
    } else {
        Write-Host "✗ لم يتم العثور على Java JDK على جهازك!" -ForegroundColor Red
        Write-Host "يرجى تثبيت Java 17 عبر الأمر التالي في نافذة PowerShell جديدة:" -ForegroundColor White
        Write-Host "winget install Microsoft.OpenJDK.17" -ForegroundColor Cyan
        exit 1
    }
} else {
    Write-Host "✓ Java متوفر ومثبت: $((java -version 2>&1)[0])" -ForegroundColor Green
}

# 2. التحقق من مسار Android SDK
Write-Host "`n[2/4] فحص مسار Android SDK..." -ForegroundColor Yellow
$defaultSdkPath = "$env:LOCALAPPDATA\Android\Sdk"

if (-not $env:ANDROID_HOME) {
    if (Test-Path $defaultSdkPath) {
        $env:ANDROID_HOME = $defaultSdkPath
        Write-Host "✓ تم ضبط مسار Android SDK تلقائياً: $defaultSdkPath" -ForegroundColor Green
    } else {
        Write-Host "! تنبيه: لم يتم تعيين ANDROID_HOME. سيتم محاولة البناء بالاعتماد على إعدادات النظام." -ForegroundColor Yellow
    }
} else {
    Write-Host "✓ ANDROID_HOME مضبوط مسبقاً: $env:ANDROID_HOME" -ForegroundColor Green
}

# 3. التأكد من توفر حزمة تشغيل Gradle
Write-Host "`n[3/4] فحص أداة بناء Gradle..." -ForegroundColor Yellow
$gradleCmd = Get-Command gradle -ErrorAction SilentlyContinue

$wrapperJarPath = "gradle\wrapper\gradle-wrapper.jar"
if (-not (Test-Path $wrapperJarPath)) {
    Write-Host "جاري تحميل gradle-wrapper.jar تلقائياً عبر الإنترنت..." -ForegroundColor Gray
    New-Item -ItemType Directory -Force -Path "gradle\wrapper" | Out-Null
    $wrapperUrl = "https://raw.githubusercontent.com/gradle/gradle/v8.13.0/gradle/wrapper/gradle-wrapper.jar"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $wrapperUrl -OutFile $wrapperJarPath -UseBasicParsing
        Write-Host "✓ تم تنزيل حزمة Gradle Wrapper بنجاح" -ForegroundColor Green
    } catch {
        Write-Host "! تعذر تنزيل الـ wrapper تلقائياً، سنعتمد على أداة Gradle العامة إذا كانت متوفرة." -ForegroundColor Yellow
    }
}

# 4. تنفيذ البناء وإنشاء الـ APK
Write-Host "`n[4/4] جاري تجميع وبناء ملف الـ APK (قد يستغرق 1 - 2 دقيقة في أول مرة)..." -ForegroundColor Yellow

$buildSuccess = $false

if (Test-Path ".\gradlew.bat") {
    Write-Host "تشغيل البناء عبر: .\gradlew.bat assembleDebug" -ForegroundColor Cyan
    & .\gradlew.bat assembleDebug
    if ($LASTEXITCODE -eq 0) { $buildSuccess = $true }
} elseif ($gradleCmd) {
    Write-Host "تشغيل البناء عبر أداة Gradle المثبتة: gradle :app:assembleDebug" -ForegroundColor Cyan
    & gradle :app:assembleDebug
    if ($LASTEXITCODE -eq 0) { $buildSuccess = $true }
} else {
    Write-Host "✗ لم يتم العثور على gradlew.bat أو أداة gradle!" -ForegroundColor Red
    Write-Host "يمكنك تثبيت Gradle عالمياً بكتابة:" -ForegroundColor White
    Write-Host "winget install Gradle.Gradle" -ForegroundColor Cyan
    exit 1
}

$apkPath = "app\build\outputs\apk\debug\app-debug.apk"

if ($buildSuccess -and (Test-Path $apkPath)) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "       ✓ تم إنشاء ملف الـ APK بنجاح تام!                  " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "مكان ملف التطبيق الجاهز للتثبيت:" -ForegroundColor White
    Write-Host (Resolve-Path $apkPath) -ForegroundColor Yellow

    # خيار التثبيت المباشر إذا كان الهاتف متصلاً
    $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCmd) {
        $devices = (adb devices) | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices" }
        if ($devices) {
            Write-Host "`nتم رصد هاتف متصل! هل ترغب في تثبيت الـ APK على هاتفك فوراً؟ (Y/N)" -ForegroundColor Cyan
            $ans = Read-Host
            if ($ans -eq 'Y' -or $ans -eq 'y') {
                Write-Host "جاري التثبيت على الهاتف..." -ForegroundColor Gray
                adb install -r $apkPath
                Write-Host "✓ تم التثبيت على الهاتف بنجاح!" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "`n✗ فشل تجميع الـ APK. راجع رسائل الأخطاء أعلاه." -ForegroundColor Red
    exit 1
}
