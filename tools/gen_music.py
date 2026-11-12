import numpy as np, wave, os
sr=22050
duration=48.0
n=int(sr*duration)
t=np.arange(n)/sr
rng=np.random.default_rng(20261112)
# slow breathing pad in D major
pad=np.zeros(n, dtype=np.float64)
for freq, amp, phase in [(146.83,0.10,0.0),(220.0,0.07,1.1),(293.66,0.05,2.0),(392.0,0.035,2.7),(587.33,0.018,1.7)]:
    lfo=0.75+0.25*np.sin(2*np.pi*(0.035+0.01*np.sin(phase))*t+phase)
    pad += amp*lfo*np.sin(2*np.pi*freq*t+phase)
# soft wind
wind = rng.normal(0,1,n)
wind = np.convolve(wind, np.ones(451)/451, mode='same')
wind = wind/np.max(np.abs(wind)+1e-9)*0.018
# occasional bird calls
birds=np.zeros(n,dtype=np.float64)
for start in np.arange(3.0,duration-2.0,5.7):
    i=int(start*sr); length=int(0.35*sr)
    if i+length>=n: break
    ts=np.arange(length)/sr
    base=rng.uniform(1700,2600)
    env=np.exp(-ts*9)*np.minimum(1,ts*80)
    birds[i:i+length] += 0.035*env*np.sin(2*np.pi*(base+350*np.sin(2*np.pi*7*ts))*ts)
# gentle chime notes every 12 s
chime=np.zeros(n,dtype=np.float64)
for start in [0.0, 12.0, 24.0, 36.0]:
    i=int(start*sr); length=int(3.0*sr)
    ts=np.arange(length)/sr
    env=np.exp(-ts*1.1)
    chime[i:i+length] += 0.045*env*np.sin(2*np.pi*587.33*ts)
    chime[i:i+length] += 0.035*env*np.sin(2*np.pi*880.0*ts)
signal=pad+wind+birds+chime
# normalize and loop-safe fades
signal=signal/(np.max(np.abs(signal))+1e-9)*0.55
fade=int(sr*1.2)
env=np.ones(n)
env[:fade]=np.linspace(0,1,fade)
env[-fade:]=np.linspace(1,0,fade)
signal*=env
pcm=(np.clip(signal,-1,1)*32767).astype('<i2')
path=r'D:\Godot project\NaiwaForest\assets\audio\forest_theme.wav'
with wave.open(path,'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes(pcm.tobytes())
print('WROTE', path, os.path.getsize(path))
