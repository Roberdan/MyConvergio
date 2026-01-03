'use client';

import { useState, useRef, useEffect } from 'react';
import { maestri } from '@/data';
import type { Maestro } from '@/types';

// Lazy import VoiceSession for direct component testing
import dynamic from 'next/dynamic';
const VoiceSession = dynamic(
  () => import('@/components/voice/voice-session').then(mod => ({ default: mod.VoiceSession })),
  { ssr: false, loading: () => <div className="text-white">Loading VoiceSession component...</div> }
);

interface LogEntry {
  time: string;
  type: 'info' | 'error' | 'send' | 'receive';
  message: string;
}

export default function TestVoicePage() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [status, setStatus] = useState<'idle' | 'connecting' | 'connected' | 'error'>('idle');
  const [micPermission, setMicPermission] = useState<'unknown' | 'granted' | 'denied'>('unknown');
  const [isRecording, setIsRecording] = useState(false);
  const [audioLevel, setAudioLevel] = useState(0);

  // Maestro testing state
  const [selectedMaestro, setSelectedMaestro] = useState<Maestro | null>(null);
  const [showVoiceSession, setShowVoiceSession] = useState(false);
  const [testMode, setTestMode] = useState<'raw' | 'component'>('raw');

  // Device selection state
  const [audioInputDevices, setAudioInputDevices] = useState<MediaDeviceInfo[]>([]);
  const [audioOutputDevices, setAudioOutputDevices] = useState<MediaDeviceInfo[]>([]);
  const [selectedInputDevice, setSelectedInputDevice] = useState<string>('');
  const [selectedOutputDevice, setSelectedOutputDevice] = useState<string>('');

  // Voice debug settings (moved from Settings page - Issue #61)
  const [vadThreshold, setVadThreshold] = useState(0.5);
  const [silenceDuration, setSilenceDuration] = useState(500);
  const [prefixPadding, setPrefixPadding] = useState(300);
  const [bargeInEnabled, setBargeInEnabled] = useState(true);
  const [noiseReduction, setNoiseReduction] = useState<'none' | 'near_field' | 'far_field'>('near_field');
  const [voiceTemperature, setVoiceTemperature] = useState(0.8);

  const wsRef = useRef<WebSocket | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const processorRef = useRef<ScriptProcessorNode | null>(null);
  const isRecordingRef = useRef(false);
  const levelAnimationRef = useRef<number | null>(null);
  const waveformCanvasRef = useRef<HTMLCanvasElement | null>(null);

  // Audio playback for Azure responses
  const playbackContextRef = useRef<AudioContext | null>(null);
  const audioQueueRef = useRef<Float32Array[]>([]);
  const isPlayingRef = useRef(false);

  const addLog = (type: LogEntry['type'], message: string) => {
    const time = new Date().toLocaleTimeString('it-IT', { hour12: false });
    setLogs(prev => [...prev, { time, type, message }].slice(-100));
  };

  // Enumerate audio devices
  const enumerateDevices = async () => {
    try {
      // Need to request permission first to get device labels
      await navigator.mediaDevices.getUserMedia({ audio: true });
      const devices = await navigator.mediaDevices.enumerateDevices();

      const inputs = devices.filter(d => d.kind === 'audioinput');
      const outputs = devices.filter(d => d.kind === 'audiooutput');

      setAudioInputDevices(inputs);
      setAudioOutputDevices(outputs);

      // Set default selections if not already set
      if (!selectedInputDevice && inputs.length > 0) {
        setSelectedInputDevice(inputs[0].deviceId);
      }
      if (!selectedOutputDevice && outputs.length > 0) {
        setSelectedOutputDevice(outputs[0].deviceId);
      }

      addLog('info', `📱 Found ${inputs.length} microphones, ${outputs.length} speakers`);
      inputs.forEach((d, i) => addLog('info', `   🎤 Input ${i + 1}: ${d.label || 'Unknown'}`));
      outputs.forEach((d, i) => addLog('info', `   🔊 Output ${i + 1}: ${d.label || 'Unknown'}`));
    } catch (err) {
      addLog('error', `❌ Failed to enumerate devices: ${err}`);
    }
  };

  // Enumerate devices on mount
  useEffect(() => {
    enumerateDevices();
    // Also listen for device changes
    navigator.mediaDevices.addEventListener('devicechange', enumerateDevices);
    return () => {
      navigator.mediaDevices.removeEventListener('devicechange', enumerateDevices);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- Run once on mount, callback identity doesn't matter
  }, []);

  // Initialize playback context with selected output device
  const initPlayback = async () => {
    if (!playbackContextRef.current) {
      const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;

      // Try to create AudioContext with selected output device (Chrome 110+)
      try {
        const options: AudioContextOptions & { sinkId?: string } = { sampleRate: 24000 };
        if (selectedOutputDevice) {
          options.sinkId = selectedOutputDevice;
        }
        playbackContextRef.current = new AudioContextClass(options);
      } catch {
        // Fallback: create without sinkId
        playbackContextRef.current = new AudioContextClass({ sampleRate: 24000 });
      }

      // Try to set sink ID if the AudioContext supports it (newer browsers)
      if (selectedOutputDevice && 'setSinkId' in playbackContextRef.current) {
        try {
          await (playbackContextRef.current as AudioContext & { setSinkId: (id: string) => Promise<void> }).setSinkId(selectedOutputDevice);
          const deviceLabel = audioOutputDevices.find(d => d.deviceId === selectedOutputDevice)?.label || 'selected';
          addLog('info', `🔊 Audio output set to: ${deviceLabel}`);
        } catch (err) {
          addLog('error', `⚠️ Could not set output device: ${err}`);
        }
      }

      addLog('info', '🔊 Audio playback context initialized at 24kHz');
    }
  };

  // Play queued audio
  const playNextAudio = () => {
    if (!playbackContextRef.current || audioQueueRef.current.length === 0) {
      isPlayingRef.current = false;
      return;
    }

    isPlayingRef.current = true;
    const samples = audioQueueRef.current.shift()!;

    const buffer = playbackContextRef.current.createBuffer(1, samples.length, 24000);
    buffer.getChannelData(0).set(samples);

    const source = playbackContextRef.current.createBufferSource();
    source.buffer = buffer;
    source.connect(playbackContextRef.current.destination);
    source.onended = () => playNextAudio();
    source.start();
  };

  // Queue audio for playback
  const queueAudio = async (base64Audio: string) => {
    await initPlayback();

    // Decode base64 to PCM16
    const binaryString = atob(base64Audio);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    // Convert PCM16 to Float32
    const pcm16 = new Int16Array(bytes.buffer);
    const float32 = new Float32Array(pcm16.length);
    for (let i = 0; i < pcm16.length; i++) {
      float32[i] = pcm16[i] / 32768;
    }

    audioQueueRef.current.push(float32);

    // Log first audio chunk only to avoid spam
    if (audioQueueRef.current.length === 1) {
      addLog('info', `🔊 First audio chunk queued (${float32.length} samples, starting playback...)`);
    }

    if (!isPlayingRef.current) {
      playNextAudio();
    }
  };

  // Test 1: Check microphone permission
  const testMicrophone = async () => {
    const deviceLabel = audioInputDevices.find(d => d.deviceId === selectedInputDevice)?.label || 'default';
    addLog('info', `Testing microphone: ${deviceLabel}...`);
    try {
      // Use selected device if available
      const constraints: MediaStreamConstraints = {
        audio: selectedInputDevice
          ? { deviceId: { exact: selectedInputDevice } }
          : true
      };
      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      setMicPermission('granted');
      addLog('info', `✅ Microphone access GRANTED: ${deviceLabel}`);

      // Test audio context
      const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      audioContextRef.current = new AudioContextClass();
      mediaStreamRef.current = stream;

      // Create analyser for waveform visualization
      analyserRef.current = audioContextRef.current.createAnalyser();
      analyserRef.current.fftSize = 2048; // Higher for better waveform
      const source = audioContextRef.current.createMediaStreamSource(stream);
      source.connect(analyserRef.current);

      addLog('info', `✅ AudioContext created, sampleRate: ${audioContextRef.current.sampleRate}Hz`);

      // Start waveform visualization
      isRecordingRef.current = true;
      setIsRecording(true);

      const canvas = waveformCanvasRef.current;
      if (!canvas) {
        addLog('error', '❌ Canvas not found');
        return;
      }
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        addLog('error', '❌ Canvas context not available');
        return;
      }

      const timeDataArray = new Uint8Array(analyserRef.current.fftSize);

      const drawWaveform = () => {
        if (!analyserRef.current || !isRecordingRef.current) return;

        levelAnimationRef.current = requestAnimationFrame(drawWaveform);

        // Get time domain data for waveform
        analyserRef.current.getByteTimeDomainData(timeDataArray);

        // Calculate audio level (RMS)
        let sum = 0;
        for (let i = 0; i < timeDataArray.length; i++) {
          const value = (timeDataArray[i] - 128) / 128;
          sum += value * value;
        }
        const rms = Math.sqrt(sum / timeDataArray.length);
        const level = Math.min(100, rms * 400);
        setAudioLevel(level);

        // Draw waveform
        const width = canvas.width;
        const height = canvas.height;

        ctx.fillStyle = 'rgb(15, 23, 42)'; // slate-900
        ctx.fillRect(0, 0, width, height);

        ctx.lineWidth = 2;
        ctx.strokeStyle = level > 5 ? 'rgb(34, 197, 94)' : 'rgb(100, 116, 139)'; // green-500 or slate-500
        ctx.beginPath();

        const sliceWidth = width / timeDataArray.length;
        let x = 0;

        for (let i = 0; i < timeDataArray.length; i++) {
          const v = timeDataArray[i] / 128.0;
          const y = (v * height) / 2;

          if (i === 0) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }

          x += sliceWidth;
        }

        ctx.lineTo(width, height / 2);
        ctx.stroke();

        // Draw level bar at the bottom
        const gradient = ctx.createLinearGradient(0, 0, (width * level) / 100, 0);
        gradient.addColorStop(0, 'rgb(34, 197, 94)');    // green
        gradient.addColorStop(0.7, 'rgb(234, 179, 8)');  // yellow
        gradient.addColorStop(1, 'rgb(239, 68, 68)');    // red
        ctx.fillStyle = gradient;
        ctx.fillRect(0, height - 6, (width * level) / 100, 6);
      };

      drawWaveform();
      addLog('info', '🎤 Waveform visualization started - speak to see the wave!');

    } catch (err) {
      setMicPermission('denied');
      addLog('error', `❌ Microphone access DENIED: ${err}`);
    }
  };

  // Stop waveform visualization
  const stopWaveform = () => {
    isRecordingRef.current = false;
    setIsRecording(false);

    if (levelAnimationRef.current) {
      cancelAnimationFrame(levelAnimationRef.current);
      levelAnimationRef.current = null;
    }

    // Clear canvas
    const canvas = waveformCanvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.fillStyle = 'rgb(15, 23, 42)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
      }
    }

    setAudioLevel(0);
    addLog('info', '🎤 Waveform stopped');
  };

  const stopMicrophoneTest = () => {
    isRecordingRef.current = false;
    setIsRecording(false);
    if (levelAnimationRef.current) {
      cancelAnimationFrame(levelAnimationRef.current);
      levelAnimationRef.current = null;
    }
    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach(t => t.stop());
      mediaStreamRef.current = null;
    }
    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }
    setAudioLevel(0);
    addLog('info', '🎤 Microphone test stopped');
  };

  // Test 2: Connect to WebSocket proxy
  const testWebSocket = async (maestroId?: string) => {
    const id = maestroId || selectedMaestro?.id || 'test-debug';
    addLog('info', `Connecting to WebSocket proxy on port 3001 with maestroId=${id}...`);
    setStatus('connecting');

    try {
      const host = window.location.hostname;
      const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
      const wsUrl = `${protocol}://${host}:3001?maestroId=${id}`;
      addLog('send', `Connecting to: ${wsUrl}`);

      const ws = new WebSocket(wsUrl);
      wsRef.current = ws;

      ws.onopen = () => {
        addLog('info', '✅ WebSocket OPEN - Proxy connected');
        setStatus('connected');
      };

      ws.onmessage = async (event) => {
        try {
          // Handle both string and blob data
          let msgText: string;
          if (event.data instanceof Blob) {
            msgText = await event.data.text();
          } else if (typeof event.data === 'string') {
            msgText = event.data;
          } else {
            addLog('receive', `[binary] ${event.data?.length || 'unknown'} bytes`);
            return;
          }

          const data = JSON.parse(msgText);
          addLog('receive', `[${data.type}] ${JSON.stringify(data).substring(0, 300)}`);

          if (data.type === 'proxy.ready') {
            addLog('info', '✅ Proxy ready - Azure connection established');
          }
          if (data.type === 'session.created') {
            addLog('info', '✅ Session created by Azure');
          }
          if (data.type === 'session.updated') {
            addLog('info', '✅ Session config accepted by Azure');
          }
          if (data.type === 'error') {
            addLog('error', `❌ Azure error: ${JSON.stringify(data.error)}`);
          }
          // =========================================================================
          // AUDIO OUTPUT EVENTS - HANDLE BOTH PREVIEW AND GA API FORMATS!
          // =========================================================================
          // CRITICAL: Azure has TWO API versions with DIFFERENT event names:
          //   - Preview API (gpt-4o-realtime-preview): response.audio.delta
          //   - GA API (gpt-realtime): response.output_audio.delta
          // If you only check one, audio may arrive but never play!
          // =========================================================================
          if ((data.type === 'response.audio.delta' || data.type === 'response.output_audio.delta') && data.delta) {
            queueAudio(data.delta);
          }
          // TRANSCRIPT - same Preview vs GA pattern
          if ((data.type === 'response.audio_transcript.delta' || data.type === 'response.output_audio_transcript.delta') && data.delta) {
            addLog('info', `🗣️ AI: ${data.delta}`);
          }
          if (data.type === 'response.done') {
            addLog('info', '✅ Response complete');
          }
          // Handle speech detected
          if (data.type === 'input_audio_buffer.speech_started') {
            addLog('info', '🎤 Speech detected!');
          }
          if (data.type === 'input_audio_buffer.speech_stopped') {
            addLog('info', '🎤 Speech ended, processing...');
          }
        } catch (e) {
          addLog('receive', `[parse error] ${e} - raw: ${String(event.data).substring(0, 100)}`);
        }
      };

      ws.onerror = (err) => {
        addLog('error', `❌ WebSocket error: ${err}`);
        setStatus('error');
      };

      ws.onclose = (event) => {
        addLog('info', `WebSocket closed: code=${event.code}, reason=${event.reason || 'none'}`);
        setStatus('idle');
      };

    } catch (err) {
      addLog('error', `❌ Failed to connect: ${err}`);
      setStatus('error');
    }
  };

  // Test 3: Send session.update with different formats
  const sendSessionUpdate = (format: 'preview' | 'nested' | 'flat' | 'minimal') => {
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
      addLog('error', '❌ WebSocket not connected');
      return;
    }

    let config;
    if (format === 'preview') {
      // Azure Preview API format (gpt-4o-realtime-preview) - NO modalities, NO type:realtime
      config = {
        type: 'session.update',
        session: {
          voice: 'alloy',
          instructions: 'You are a helpful assistant. Respond in Italian.',
          input_audio_format: 'pcm16',
          input_audio_transcription: { model: 'whisper-1' },
          turn_detection: {
            type: 'server_vad',
            threshold: 0.5,
            prefix_padding_ms: 300,
            silence_duration_ms: 500,
            create_response: true
          }
        }
      };
    } else if (format === 'nested') {
      // Azure GA nested format (from Swift app)
      config = {
        type: 'session.update',
        session: {
          type: 'realtime',
          instructions: 'You are a helpful assistant. Respond in Italian.',
          output_modalities: ['audio'],
          audio: {
            input: {
              transcription: { model: 'whisper-1' },
              format: { type: 'audio/pcm', rate: 24000 },
              turn_detection: {
                type: 'server_vad',
                threshold: 0.5,
                prefix_padding_ms: 300,
                silence_duration_ms: 200,
                create_response: true
              }
            },
            output: {
              voice: 'alloy',
              format: { type: 'audio/pcm', rate: 24000 }
            }
          }
        }
      };
    } else if (format === 'flat') {
      // OpenAI standard flat format
      config = {
        type: 'session.update',
        session: {
          modalities: ['text', 'audio'],
          instructions: 'You are a helpful assistant. Respond in Italian.',
          voice: 'alloy',
          input_audio_format: 'pcm16',
          output_audio_format: 'pcm16',
          input_audio_transcription: { model: 'whisper-1' },
          turn_detection: {
            type: 'server_vad',
            threshold: 0.5,
            prefix_padding_ms: 300,
            silence_duration_ms: 500
          }
        }
      };
    } else {
      // Minimal Azure GA format - VERIFIED WORKING via websocat
      // Requirements: session.type is REQUIRED, voice must be in audio.output
      config = {
        type: 'session.update',
        session: {
          type: 'realtime',  // REQUIRED by Azure GA
          instructions: 'You are a helpful assistant. Respond in Italian.',
          audio: {
            output: { voice: 'alloy' }  // voice goes here, not top-level
          }
        }
      };
    }

    addLog('send', `Sending ${format} session.update: ${JSON.stringify(config).substring(0, 300)}...`);
    wsRef.current.send(JSON.stringify(config));
  };

  // Send session.update using debug settings from UI (Issue #61)
  const sendDebugSessionUpdate = () => {
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
      addLog('error', '❌ WebSocket not connected');
      return;
    }

    const config = {
      type: 'session.update',
      session: {
        voice: 'alloy',
        instructions: 'You are a helpful assistant. Respond in Italian.',
        input_audio_format: 'pcm16',
        input_audio_transcription: { model: 'whisper-1' },
        temperature: voiceTemperature,
        ...(noiseReduction !== 'none' && {
          input_audio_noise_reduction: { type: noiseReduction }
        }),
        turn_detection: {
          type: 'server_vad',
          threshold: vadThreshold,
          prefix_padding_ms: prefixPadding,
          silence_duration_ms: silenceDuration,
          create_response: true,
          interrupt_response: bargeInEnabled,
        }
      }
    };

    addLog('send', `Sending DEBUG session.update with custom settings: ${JSON.stringify(config).substring(0, 400)}...`);
    wsRef.current.send(JSON.stringify(config));
  };

  // Debug: Show full configuration status
  const debugConfig = async () => {
    addLog('info', 'Fetching debug configuration...');
    try {
      const res = await fetch('/api/debug/config');
      const data = await res.json();

      addLog('info', '=== CHAT CONFIGURATION ===');
      addLog('info', `   Provider: ${data.chat.provider}`);
      addLog('info', `   Model: ${data.chat.model}`);
      addLog('info', `   Endpoint: ${data.chat.endpoint}`);
      addLog('info', `   Has API Key: ${data.chat.hasApiKey}`);

      addLog('info', '=== REALTIME/VOICE CONFIGURATION ===');
      addLog('info', `   Provider: ${data.realtime.provider}`);
      addLog('info', `   Model: ${data.realtime.model}`);
      addLog('info', `   Endpoint: ${data.realtime.endpoint}`);
      addLog('info', `   Has API Key: ${data.realtime.hasApiKey}`);

      addLog('info', '=== ENVIRONMENT VARIABLES ===');
      for (const [key, value] of Object.entries(data.envVars)) {
        const status = value === true ? '✅' : value === false ? '❌' : `${value}`;
        addLog('info', `   ${key}: ${status}`);
      }

      addLog('info', '=== DIAGNOSIS ===');
      for (const issue of data.diagnosis) {
        addLog(issue.startsWith('❌') ? 'error' : 'info', `   ${issue}`);
      }
    } catch (err) {
      addLog('error', `❌ Debug config failed: ${err}`);
    }
  };

  // Test: Check API configuration
  const checkApiConfig = async () => {
    addLog('info', 'Checking API configuration...');
    try {
      // Check Azure Realtime token endpoint
      const tokenRes = await fetch('/api/realtime/token');
      const tokenData = await tokenRes.json();
      if (tokenData.configured) {
        addLog('info', `✅ Azure Realtime configured: provider=${tokenData.provider}, port=${tokenData.proxyPort}`);
      } else if (tokenData.error) {
        addLog('error', `❌ Azure Realtime NOT configured: ${tokenData.error}`);
        if (tokenData.missingVariables) {
          addLog('error', `   Missing: ${tokenData.missingVariables.join(', ')}`);
        }
      } else {
        addLog('error', '❌ Azure Realtime NOT configured');
      }

      // Check Chat API with proper systemPrompt
      const chatRes = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [{ role: 'user', content: 'Rispondi solo "OK"' }],
          systemPrompt: 'Sei un assistente. Rispondi brevemente.',
          maestroId: 'euclide'
        })
      });

      if (chatRes.ok) {
        const data = await chatRes.json();
        addLog('info', `✅ Chat API working: provider=${data.provider}, model=${data.model}`);
        addLog('info', `   Response: ${data.content?.substring(0, 100) || 'empty'}`);
      } else {
        const err = await chatRes.text();
        addLog('error', `❌ Chat API error: ${chatRes.status} - ${err.substring(0, 200)}`);
      }
    } catch (err) {
      addLog('error', `❌ API check failed: ${err}`);
    }
  };

  // Test: Chat-only (no voice)
  const testChatOnly = async () => {
    addLog('info', 'Testing chat API (text only, no voice)...');
    try {
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [{ role: 'user', content: 'Ciao! Dimmi chi sei in una frase.' }],
          systemPrompt: 'Sei Euclide di Alessandria, il famoso matematico greco. Rispondi in italiano in modo amichevole.',
          maestroId: 'euclide'
        })
      });

      if (!res.ok) {
        const errText = await res.text();
        addLog('error', `❌ Chat failed: ${res.status} - ${errText.substring(0, 200)}`);
        return;
      }

      // Parse JSON response (not streaming)
      const data = await res.json();
      addLog('info', `✅ Chat response from ${data.provider}/${data.model}:`);
      addLog('receive', data.content || 'No content');
      if (data.usage) {
        addLog('info', `   Tokens: ${data.usage.prompt_tokens} prompt + ${data.usage.completion_tokens} completion = ${data.usage.total_tokens} total`);
      }
    } catch (err) {
      addLog('error', `❌ Chat error: ${err}`);
    }
  };

  // Test 4: Send a text message to trigger response
  const sendTestMessage = () => {
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
      addLog('error', '❌ WebSocket not connected');
      return;
    }

    const msg = {
      type: 'conversation.item.create',
      item: {
        type: 'message',
        role: 'user',
        content: [{ type: 'input_text', text: 'Ciao! Dimmi qualcosa in italiano.' }]
      }
    };
    addLog('send', `Sending message: ${JSON.stringify(msg)}`);
    wsRef.current.send(JSON.stringify(msg));

    // Trigger response
    setTimeout(() => {
      if (wsRef.current?.readyState === WebSocket.OPEN) {
        const resp = { type: 'response.create' };
        addLog('send', 'Sending response.create');
        wsRef.current.send(JSON.stringify(resp));
      }
    }, 100);
  };

  // Test 5: Send audio data
  const startSendingAudio = () => {
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
      addLog('error', '❌ WebSocket not connected');
      return;
    }
    if (!audioContextRef.current || !mediaStreamRef.current) {
      addLog('error', '❌ Microphone not initialized');
      return;
    }

    addLog('info', 'Starting audio capture and sending...');

    const inputSampleRate = audioContextRef.current.sampleRate; // Usually 48000
    const targetSampleRate = 24000; // Azure requires 24kHz
    const resampleRatio = inputSampleRate / targetSampleRate;

    addLog('info', `Resampling from ${inputSampleRate}Hz to ${targetSampleRate}Hz (ratio: ${resampleRatio})`);

    const source = audioContextRef.current.createMediaStreamSource(mediaStreamRef.current);
    processorRef.current = audioContextRef.current.createScriptProcessor(4096, 1, 1);

    let audioChunkCount = 0;
    processorRef.current.onaudioprocess = (e) => {
      if (wsRef.current?.readyState !== WebSocket.OPEN) return;

      const inputData = e.inputBuffer.getChannelData(0);

      // Resample from inputSampleRate to 24kHz
      const outputLength = Math.floor(inputData.length / resampleRatio);
      const pcm16 = new Int16Array(outputLength);

      for (let i = 0; i < outputLength; i++) {
        // Linear interpolation for resampling
        const srcIndex = i * resampleRatio;
        const srcIndexFloor = Math.floor(srcIndex);
        const srcIndexCeil = Math.min(srcIndexFloor + 1, inputData.length - 1);
        const fraction = srcIndex - srcIndexFloor;

        const sample = inputData[srcIndexFloor] * (1 - fraction) + inputData[srcIndexCeil] * fraction;
        pcm16[i] = Math.max(-32768, Math.min(32767, Math.floor(sample * 32768)));
      }

      // Convert to base64
      const base64 = btoa(String.fromCharCode(...new Uint8Array(pcm16.buffer)));

      wsRef.current.send(JSON.stringify({
        type: 'input_audio_buffer.append',
        audio: base64
      }));

      audioChunkCount++;
      if (audioChunkCount % 10 === 0) {
        addLog('send', `Sent ${audioChunkCount} audio chunks (resampled to 24kHz)`);
      }
    };

    source.connect(processorRef.current);
    processorRef.current.connect(audioContextRef.current.destination);

    addLog('info', '🎤 Audio streaming started at 24kHz - speak now!');
  };

  const stopSendingAudio = () => {
    if (processorRef.current) {
      processorRef.current.disconnect();
      processorRef.current = null;
      addLog('info', '🎤 Audio streaming stopped');
    }
  };

  const disconnect = () => {
    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }
    stopSendingAudio();
    // Clear audio queue and stop playback
    audioQueueRef.current = [];
    isPlayingRef.current = false;
    setStatus('idle');
    addLog('info', 'Disconnected');
  };

  // Test speakers with a beep
  const testSpeakers = async () => {
    const deviceLabel = audioOutputDevices.find(d => d.deviceId === selectedOutputDevice)?.label || 'default';
    addLog('info', `Testing speakers: ${deviceLabel}...`);
    try {
      const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;

      // Try to create with selected output device
      let ctx: AudioContext;
      try {
        const options: AudioContextOptions & { sinkId?: string } = {};
        if (selectedOutputDevice) {
          options.sinkId = selectedOutputDevice;
        }
        ctx = new AudioContextClass(options);
      } catch {
        ctx = new AudioContextClass();
      }

      // Try to set sink ID if supported
      if (selectedOutputDevice && 'setSinkId' in ctx) {
        try {
          await (ctx as AudioContext & { setSinkId: (id: string) => Promise<void> }).setSinkId(selectedOutputDevice);
          addLog('info', `🔊 Output device set to: ${deviceLabel}`);
        } catch (err) {
          addLog('error', `⚠️ Could not set output device: ${err}`);
        }
      }

      const oscillator = ctx.createOscillator();
      const gainNode = ctx.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);

      oscillator.frequency.value = 440; // A4 note
      oscillator.type = 'sine';
      gainNode.gain.value = 0.3;

      oscillator.start();
      setTimeout(() => {
        oscillator.stop();
        ctx.close();
        addLog('info', `✅ Speaker test complete on ${deviceLabel} - did you hear a beep?`);
      }, 500);
    } catch (err) {
      addLog('error', `❌ Speaker test failed: ${err}`);
    }
  };

  // Test TTS with browser speech synthesis
  const testBrowserTTS = () => {
    addLog('info', 'Testing browser TTS...');
    if (!('speechSynthesis' in window)) {
      addLog('error', '❌ Browser TTS not supported');
      return;
    }

    const utterance = new SpeechSynthesisUtterance('Ciao! Questo è un test del sistema audio.');
    utterance.lang = 'it-IT';
    utterance.onend = () => addLog('info', '✅ Browser TTS complete');
    utterance.onerror = (e) => addLog('error', `❌ Browser TTS error: ${e.error}`);
    speechSynthesis.speak(utterance);
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      isRecordingRef.current = false;
      if (levelAnimationRef.current) {
        cancelAnimationFrame(levelAnimationRef.current);
      }
      // Inline cleanup instead of calling disconnect (which would cause re-render loop)
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
      if (processorRef.current) {
        processorRef.current.disconnect();
        processorRef.current = null;
      }
      audioQueueRef.current = [];
      isPlayingRef.current = false;
      if (mediaStreamRef.current) {
        mediaStreamRef.current.getTracks().forEach(t => t.stop());
      }
      if (audioContextRef.current) {
        audioContextRef.current.close();
      }
      if (playbackContextRef.current) {
        playbackContextRef.current.close();
      }
    };
  }, []);

  return (
    <div className="min-h-screen bg-gray-900 text-white p-4">
      <h1 className="text-2xl font-bold mb-4">🔧 Voice Debug Test Page</h1>

      {/* Status */}
      <div className="mb-4 p-4 bg-gray-800 rounded">
        <div className="flex gap-4 items-center mb-3">
          <span>WebSocket: </span>
          <span className={`px-2 py-1 rounded ${
            status === 'connected' ? 'bg-green-600' :
            status === 'connecting' ? 'bg-yellow-600' :
            status === 'error' ? 'bg-red-600' : 'bg-gray-600'
          }`}>{status}</span>

          <span>Mic: </span>
          <span className={`px-2 py-1 rounded ${
            micPermission === 'granted' ? 'bg-green-600' :
            micPermission === 'denied' ? 'bg-red-600' : 'bg-gray-600'
          }`}>{micPermission}</span>

          {isRecording && (
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-red-500 rounded-full animate-pulse" />
              <span className="text-sm">LIVE</span>
              <span className="text-sm text-gray-400">Level: {Math.round(audioLevel)}%</span>
              <button
                onClick={stopWaveform}
                className="px-2 py-1 bg-red-600 hover:bg-red-500 rounded text-xs"
              >
                Stop
              </button>
            </div>
          )}
        </div>

        {/* Waveform Canvas */}
        <div className="relative">
          <canvas
            ref={waveformCanvasRef}
            width={800}
            height={120}
            className="w-full h-[120px] rounded-lg bg-slate-900 border border-gray-700"
          />
          {!isRecording && (
            <div className="absolute inset-0 flex items-center justify-center text-gray-500">
              Click &quot;Test Microphone&quot; to see waveform
            </div>
          )}
        </div>
      </div>

      {/* Device Selection */}
      <div className="mb-4 p-4 bg-gradient-to-r from-gray-800 to-gray-700 rounded border border-gray-600">
        <h2 className="font-bold mb-3 text-lg">🎛️ Audio Device Selection</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Microphone Selection */}
          <div>
            <label className="block text-sm font-medium mb-1">🎤 Microphone (Input)</label>
            <select
              value={selectedInputDevice}
              onChange={(e) => {
                setSelectedInputDevice(e.target.value);
                addLog('info', `🎤 Selected input: ${audioInputDevices.find(d => d.deviceId === e.target.value)?.label || 'Unknown'}`);
                // Reset playback context to use new device
                if (playbackContextRef.current) {
                  playbackContextRef.current.close();
                  playbackContextRef.current = null;
                }
              }}
              className="w-full p-2 rounded bg-gray-900 border border-gray-600 text-white"
            >
              {audioInputDevices.length === 0 && (
                <option value="">No microphones found</option>
              )}
              {audioInputDevices.map((device) => (
                <option key={device.deviceId} value={device.deviceId}>
                  {device.label || `Microphone ${device.deviceId.slice(0, 8)}...`}
                </option>
              ))}
            </select>
          </div>

          {/* Speaker Selection */}
          <div>
            <label className="block text-sm font-medium mb-1">🔊 Speaker (Output)</label>
            <select
              value={selectedOutputDevice}
              onChange={(e) => {
                setSelectedOutputDevice(e.target.value);
                addLog('info', `🔊 Selected output: ${audioOutputDevices.find(d => d.deviceId === e.target.value)?.label || 'Unknown'}`);
                // Reset playback context to use new device
                if (playbackContextRef.current) {
                  playbackContextRef.current.close();
                  playbackContextRef.current = null;
                }
              }}
              className="w-full p-2 rounded bg-gray-900 border border-gray-600 text-white"
            >
              {audioOutputDevices.length === 0 && (
                <option value="">No speakers found</option>
              )}
              {audioOutputDevices.map((device) => (
                <option key={device.deviceId} value={device.deviceId}>
                  {device.label || `Speaker ${device.deviceId.slice(0, 8)}...`}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="mt-3 flex gap-2">
          <button
            onClick={enumerateDevices}
            className="px-3 py-1 bg-gray-600 hover:bg-gray-500 rounded text-sm"
          >
            🔄 Refresh Devices
          </button>
          <span className="text-xs text-gray-400 self-center">
            {audioInputDevices.length} mics, {audioOutputDevices.length} speakers
          </span>
        </div>
      </div>

      {/* Voice Debug Settings (Issue #61 - moved from Settings page) */}
      <div className="mb-4 p-4 bg-gradient-to-r from-amber-900 to-orange-900 rounded border-2 border-amber-500">
        <h2 className="font-bold mb-3 text-xl">🎛️ Voice Session Debug Settings</h2>
        <p className="text-sm text-amber-200 mb-4">
          Questi controlli sono solo per debug. In produzione, i valori sono hardcoded in use-voice-session.ts
        </p>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {/* VAD Threshold */}
          <div className="bg-black/30 rounded p-3">
            <label className="block text-sm text-amber-300 mb-1">
              VAD Threshold: {vadThreshold.toFixed(2)}
            </label>
            <input
              type="range"
              min="0"
              max="1"
              step="0.05"
              value={vadThreshold}
              onChange={(e) => setVadThreshold(parseFloat(e.target.value))}
              className="w-full accent-amber-500"
            />
            <div className="flex justify-between text-xs text-gray-400 mt-1">
              <span>Sensibile</span>
              <span>Ignora rumore</span>
            </div>
          </div>

          {/* Silence Duration */}
          <div className="bg-black/30 rounded p-3">
            <label className="block text-sm text-amber-300 mb-1">
              Silence Duration: {silenceDuration}ms
            </label>
            <input
              type="range"
              min="100"
              max="1000"
              step="50"
              value={silenceDuration}
              onChange={(e) => setSilenceDuration(parseInt(e.target.value))}
              className="w-full accent-amber-500"
            />
            <div className="flex justify-between text-xs text-gray-400 mt-1">
              <span>Veloce</span>
              <span>Lento</span>
            </div>
          </div>

          {/* Prefix Padding */}
          <div className="bg-black/30 rounded p-3">
            <label className="block text-sm text-amber-300 mb-1">
              Prefix Padding: {prefixPadding}ms
            </label>
            <input
              type="range"
              min="100"
              max="500"
              step="50"
              value={prefixPadding}
              onChange={(e) => setPrefixPadding(parseInt(e.target.value))}
              className="w-full accent-amber-500"
            />
            <div className="flex justify-between text-xs text-gray-400 mt-1">
              <span>100ms</span>
              <span>500ms</span>
            </div>
          </div>

          {/* Temperature */}
          <div className="bg-black/30 rounded p-3">
            <label className="block text-sm text-amber-300 mb-1">
              Temperature: {voiceTemperature.toFixed(1)}
            </label>
            <input
              type="range"
              min="0"
              max="1"
              step="0.1"
              value={voiceTemperature}
              onChange={(e) => setVoiceTemperature(parseFloat(e.target.value))}
              className="w-full accent-amber-500"
            />
            <div className="flex justify-between text-xs text-gray-400 mt-1">
              <span>Deterministico</span>
              <span>Creativo</span>
            </div>
          </div>

          {/* Noise Reduction */}
          <div className="bg-black/30 rounded p-3">
            <label className="block text-sm text-amber-300 mb-1">
              Noise Reduction
            </label>
            <select
              value={noiseReduction}
              onChange={(e) => setNoiseReduction(e.target.value as 'none' | 'near_field' | 'far_field')}
              className="w-full px-2 py-1 rounded bg-gray-800 text-white border border-amber-500"
            >
              <option value="none">None</option>
              <option value="near_field">Near Field (headphones/close mic)</option>
              <option value="far_field">Far Field (laptop/conference)</option>
            </select>
          </div>

          {/* Barge-in Toggle */}
          <div className="bg-black/30 rounded p-3">
            <label className="block text-sm text-amber-300 mb-1">
              Barge-in (Interruption)
            </label>
            <button
              onClick={() => setBargeInEnabled(!bargeInEnabled)}
              className={`w-full px-3 py-2 rounded font-medium ${
                bargeInEnabled
                  ? 'bg-green-600 hover:bg-green-700'
                  : 'bg-red-600 hover:bg-red-700'
              }`}
            >
              {bargeInEnabled ? '✅ Enabled' : '❌ Disabled'}
            </button>
            <p className="text-xs text-gray-400 mt-1">
              {bargeInEnabled ? 'User can interrupt AI' : 'AI speaks without interruption'}
            </p>
          </div>
        </div>

        {/* Current Config Summary */}
        <div className="mt-4 p-3 bg-black/50 rounded font-mono text-xs text-amber-200">
          <strong>Session Config Preview:</strong>
          <pre className="mt-2 overflow-x-auto">
{JSON.stringify({
  input_audio_noise_reduction: noiseReduction === 'none' ? undefined : { type: noiseReduction },
  turn_detection: {
    type: 'server_vad',
    threshold: vadThreshold,
    prefix_padding_ms: prefixPadding,
    silence_duration_ms: silenceDuration,
    create_response: true,
    interrupt_response: bargeInEnabled,
  },
  temperature: voiceTemperature,
}, null, 2)}
          </pre>
          <button
            onClick={sendDebugSessionUpdate}
            disabled={status !== 'connected'}
            className="mt-3 w-full px-4 py-2 bg-amber-600 hover:bg-amber-700 rounded font-bold disabled:opacity-50 disabled:cursor-not-allowed"
          >
            🔧 Apply Debug Settings to Session
          </button>
          <p className="text-xs text-gray-400 mt-1">
            Connect first, then click to send session.update with these settings
          </p>
        </div>
      </div>

      {/* Audio Tests */}
      <div className="mb-4 p-4 bg-gray-800 rounded">
        <h2 className="font-bold mb-2">🔊 Audio Hardware Tests</h2>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={testSpeakers}
            className="px-4 py-2 bg-cyan-600 hover:bg-cyan-700 rounded"
          >
            Test Speakers (Beep)
          </button>
          <button
            onClick={testBrowserTTS}
            className="px-4 py-2 bg-cyan-600 hover:bg-cyan-700 rounded"
          >
            Test Browser TTS
          </button>
          <button
            onClick={testMicrophone}
            disabled={isRecording}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded disabled:opacity-50"
          >
            Test Microphone
          </button>
          <button
            onClick={stopMicrophoneTest}
            disabled={!isRecording}
            className="px-4 py-2 bg-gray-600 hover:bg-gray-700 rounded disabled:opacity-50"
          >
            Stop Mic Test
          </button>
        </div>
      </div>

      {/* API Configuration Check */}
      <div className="mb-4 p-4 bg-gray-800 rounded">
        <h2 className="font-bold mb-2">🔧 API Configuration</h2>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={debugConfig}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded"
          >
            🔍 Debug Config (Full)
          </button>
          <button
            onClick={checkApiConfig}
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded"
          >
            Check Azure Config
          </button>
          <button
            onClick={testChatOnly}
            className="px-4 py-2 bg-teal-600 hover:bg-teal-700 rounded"
          >
            Test Chat API (No Voice)
          </button>
        </div>
      </div>

      {/* MAESTRO TESTING SECTION */}
      <div className="mb-4 p-4 bg-gradient-to-r from-purple-900 to-indigo-900 rounded border-2 border-purple-500">
        <h2 className="font-bold mb-3 text-xl">🎭 PROFESSORE TEST (Confronto Diretto)</h2>
        <p className="text-sm text-purple-200 mb-4">
          Testa la connessione voice con un professore reale per confrontare con la pagina principale.
        </p>

        {/* Maestro selector */}
        <div className="flex flex-wrap gap-4 mb-4">
          <div className="flex-1 min-w-64">
            <label className="block text-sm text-purple-300 mb-1">Seleziona Professore:</label>
            <select
              value={selectedMaestro?.id || ''}
              onChange={(e) => {
                const m = maestri.find(m => m.id === e.target.value);
                setSelectedMaestro(m || null);
                addLog('info', m ? `Selected maestro: ${m.name} (${m.id})` : 'No maestro selected');
              }}
              className="w-full px-3 py-2 rounded bg-gray-800 text-white border border-purple-500"
            >
              <option value="">-- Scegli un Professore --</option>
              {maestri.map(m => (
                <option key={m.id} value={m.id}>
                  {m.name} - {m.specialty} ({m.subject})
                </option>
              ))}
            </select>
          </div>

          <div className="flex items-end gap-2">
            <div>
              <label className="block text-sm text-purple-300 mb-1">Modalita Test:</label>
              <select
                value={testMode}
                onChange={(e) => setTestMode(e.target.value as 'raw' | 'component')}
                className="px-3 py-2 rounded bg-gray-800 text-white border border-purple-500"
              >
                <option value="raw">Raw WebSocket (come test-voice)</option>
                <option value="component">VoiceSession Component (come maestri)</option>
              </select>
            </div>
          </div>
        </div>

        {/* Selected maestro info */}
        {selectedMaestro && (
          <div className="bg-black/30 rounded p-3 mb-4">
            <div className="flex items-center gap-3">
              <div
                className="w-12 h-12 rounded-full flex items-center justify-center text-2xl"
                style={{ backgroundColor: selectedMaestro.color }}
              >
                {selectedMaestro.name[0]}
              </div>
              <div>
                <h3 className="font-bold">{selectedMaestro.name}</h3>
                <p className="text-sm text-gray-400">{selectedMaestro.specialty}</p>
                <p className="text-xs text-gray-500">Voice: {selectedMaestro.voice || 'alloy'} | ID: {selectedMaestro.id}</p>
              </div>
            </div>
            <p className="mt-2 text-sm text-purple-200 italic">&ldquo;{selectedMaestro.greeting}&rdquo;</p>
          </div>
        )}

        {/* Action buttons */}
        <div className="flex flex-wrap gap-2">
          {testMode === 'raw' ? (
            <>
              <button
                onClick={() => testWebSocket(selectedMaestro?.id)}
                disabled={!selectedMaestro || status === 'connecting'}
                className="px-4 py-2 bg-purple-600 hover:bg-purple-700 rounded disabled:opacity-50"
              >
                🔌 Connect con {selectedMaestro?.name || 'Professore'}
              </button>
              <button
                onClick={() => {
                  if (selectedMaestro) {
                    sendSessionUpdate('preview');
                    addLog('info', `Session config sent for ${selectedMaestro.name}`);
                  }
                }}
                disabled={status !== 'connected'}
                className="px-4 py-2 bg-green-600 hover:bg-green-700 rounded disabled:opacity-50"
              >
                ⚙️ Session Config
              </button>
              <button
                onClick={() => {
                  if (selectedMaestro && wsRef.current?.readyState === WebSocket.OPEN) {
                    const greeting = `Ciao! Sono uno studente. Presentati come ${selectedMaestro.name} e dimmi cosa possiamo imparare oggi.`;
                    const msg = {
                      type: 'conversation.item.create',
                      item: {
                        type: 'message',
                        role: 'user',
                        content: [{ type: 'input_text', text: greeting }]
                      }
                    };
                    wsRef.current.send(JSON.stringify(msg));
                    setTimeout(() => {
                      wsRef.current?.send(JSON.stringify({ type: 'response.create' }));
                    }, 100);
                    addLog('send', `Greeting sent to ${selectedMaestro.name}`);
                  }
                }}
                disabled={status !== 'connected'}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded disabled:opacity-50"
              >
                👋 Saluta Maestro
              </button>
            </>
          ) : (
            <button
              onClick={() => {
                if (selectedMaestro) {
                  setShowVoiceSession(true);
                  addLog('info', `Opening VoiceSession component for ${selectedMaestro.name}...`);
                }
              }}
              disabled={!selectedMaestro}
              className="px-4 py-2 bg-green-600 hover:bg-green-700 rounded disabled:opacity-50"
            >
              🎙️ Apri VoiceSession con {selectedMaestro?.name || 'Professore'}
            </button>
          )}
        </div>

        {testMode === 'component' && (
          <p className="mt-3 text-xs text-purple-300">
            ⚠️ Questo aprira il componente VoiceSession reale - quello usato nella pagina professori.
            Se funziona qui ma non nella pagina professori, il problema e nel routing/lazy loading.
          </p>
        )}
      </div>

      {/* WebSocket Tests */}
      <div className="mb-4 p-4 bg-gray-800 rounded">
        <h2 className="font-bold mb-2">🌐 WebSocket + Azure Realtime Tests (Generic)</h2>
        <div className="flex flex-wrap gap-2">
        <button
          onClick={() => testWebSocket('test-debug')}
          disabled={status === 'connecting'}
          className="px-4 py-2 bg-purple-600 hover:bg-purple-700 rounded disabled:opacity-50"
        >
          1. Connect WebSocket (test-debug)
        </button>

        <button
          onClick={() => sendSessionUpdate('preview')}
          disabled={status !== 'connected'}
          className="px-4 py-2 bg-green-600 hover:bg-green-700 rounded disabled:opacity-50"
        >
          2. Session (Preview) ⭐
        </button>

        <button
          onClick={() => sendSessionUpdate('flat')}
          disabled={status !== 'connected'}
          className="px-4 py-2 bg-orange-600 hover:bg-orange-700 rounded disabled:opacity-50"
        >
          Session (Flat/GA)
        </button>

        <button
          onClick={() => sendSessionUpdate('nested')}
          disabled={status !== 'connected'}
          className="px-4 py-2 bg-orange-600 hover:bg-orange-700 rounded disabled:opacity-50"
        >
          Session (Nested)
        </button>

        <button
          onClick={() => sendSessionUpdate('minimal')}
          disabled={status !== 'connected'}
          className="px-4 py-2 bg-gray-600 hover:bg-gray-700 rounded disabled:opacity-50"
        >
          Session (Minimal)
        </button>

        <button
          onClick={sendTestMessage}
          disabled={status !== 'connected'}
          className="px-4 py-2 bg-green-600 hover:bg-green-700 rounded disabled:opacity-50"
        >
          4. Send Test Message
        </button>

        <button
          onClick={startSendingAudio}
          disabled={status !== 'connected' || micPermission !== 'granted'}
          className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded disabled:opacity-50"
        >
          5. Start Audio Stream
        </button>

        <button
          onClick={stopSendingAudio}
          className="px-4 py-2 bg-gray-600 hover:bg-gray-700 rounded"
        >
          Stop Audio
        </button>

        <button
          onClick={disconnect}
          className="px-4 py-2 bg-gray-600 hover:bg-gray-700 rounded"
        >
          Disconnect
        </button>
        </div>
      </div>

      {/* Logs */}
      <div className="bg-black rounded p-4 h-96 overflow-y-auto font-mono text-sm">
        {logs.length === 0 ? (
          <div className="text-gray-500">Click the buttons above to start testing...</div>
        ) : (
          logs.map((log, i) => (
            <div key={i} className={`${
              log.type === 'error' ? 'text-red-400' :
              log.type === 'send' ? 'text-yellow-400' :
              log.type === 'receive' ? 'text-green-400' :
              'text-gray-300'
            }`}>
              <span className="text-gray-500">[{log.time}]</span> {log.message}
            </div>
          ))
        )}
      </div>

      {/* Instructions */}
      <div className="mt-4 p-4 bg-gray-800 rounded text-sm">
        <h2 className="font-bold mb-2">Instructions:</h2>
        <ol className="list-decimal list-inside space-y-1">
          <li><strong>🎭 MAESTRO TEST</strong> - Test with a real maestro to compare with main page</li>
          <li><strong>Check Azure Config</strong> - Verify Azure is configured and Chat API works</li>
          <li><strong>Test Chat API</strong> - Test text-only chat (no voice)</li>
          <li><strong>Test Microphone</strong> - Should show GRANTED and audio level bar</li>
          <li><strong>Connect WebSocket</strong> - Connect to proxy (wait for proxy.ready)</li>
          <li><strong>Session (Preview) ⭐</strong> - Use this for gpt-4o-realtime-preview model</li>
          <li><strong>Send Test Message</strong> - Trigger AI response (text)</li>
          <li><strong>Start Audio Stream</strong> - Speak and see if audio works</li>
        </ol>
        <p className="mt-2 text-gray-400">
          <strong>Log colors:</strong> Green = received from Azure, Yellow = sent to Azure, Red = errors
        </p>
        <p className="mt-1 text-gray-400">
          <strong>Note:</strong> For gpt-4o-realtime-preview, use Session (Preview). For GA models (gpt-realtime), try Flat/GA.
        </p>
        <p className="mt-2 text-purple-400">
          <strong>🎭 Maestro Test Mode:</strong> Use &quot;Raw WebSocket&quot; to test with the same simple logic that works on this page.
          Use &quot;VoiceSession Component&quot; to test the actual component used in the maestri page.
          If raw works but component doesn&apos;t, the bug is in VoiceSession/useVoiceSession.
        </p>
      </div>

      {/* VoiceSession Component Test Modal */}
      {showVoiceSession && selectedMaestro && (
        <VoiceSession
          maestro={selectedMaestro}
          onClose={() => {
            setShowVoiceSession(false);
            addLog('info', 'VoiceSession component closed');
          }}
          onSwitchToChat={() => {
            setShowVoiceSession(false);
            addLog('info', 'Switch to chat requested (not implemented in test page)');
          }}
        />
      )}
    </div>
  );
}
