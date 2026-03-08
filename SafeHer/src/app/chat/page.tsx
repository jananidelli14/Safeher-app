"use client"

import { Navigation } from "@/components/Navigation"
import { ShieldCheck, Send, ChevronLeft, Sparkles, Phone, RefreshCw, Wifi, WifiOff } from "lucide-react"
import Link from "next/link"
import { useState, useRef, useEffect, useCallback } from "react"

type Message = { id: number; role: 'user' | 'assistant'; text: string; time: string }

const GEMINI_KEY = "AIzaSyCqx3Tff2QzPvvHwh1H4dEhtNrMUkm_uCI"

const SYSTEM_PROMPT = `You are SafeHer AI, a compassionate women's safety assistant focused on Tamil Nadu, India.

Your expertise:
- Immediate safety advice and emotional support for women
- Emergency guidance (suggest calling 100/112/1091/108)
- Tamil Nadu specific safety knowledge: Chennai, Madurai, Coimbatore, Salem, Trichy, Vellore, Tiruppur
- Safe travel tips, safe hotels, transport safety, late-night safety
- Identifying safe and unsafe areas based on time of day

Emergency numbers to always keep in mind:
- Police: 100 | National Emergency: 112 | Women Helpline: 1091 | Ambulance: 108

Rules:
- Keep responses under 150 words — be concise and actionable
- Be warm, calm, and reassuring
- If someone seems in danger, lead with emergency numbers immediately
- Use bullet points when listing multiple tips`

const FALLBACK_RESPONSES = [
  "I'm having trouble connecting right now. If you're in immediate danger, please call **112** (Emergency) or **100** (Police) immediately. For women's helpline: **1091**. How can I help you stay safe?",
  "Connection issue — but I'm still here! For emergencies: Police **100** | Emergency **112** | Women Helpline **1091** | Ambulance **108**. What safety information do you need?",
]

async function callGemini(messages: { role: string; parts: { text: string }[] }[]): Promise<string> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 15000)

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        signal: controller.signal,
        body: JSON.stringify({
          system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: messages,
          generationConfig: {
            maxOutputTokens: 400,
            temperature: 0.7,
            topP: 0.9,
          }
        })
      }
    )

    clearTimeout(timeout)

    if (!response.ok) {
      const err = await response.json().catch(() => ({}))
      console.error("Gemini error:", response.status, err)
      throw new Error(`API error ${response.status}`)
    }

    const data = await response.json()
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text
    if (!text) throw new Error("Empty response")
    return text

  } catch (e: any) {
    clearTimeout(timeout)
    console.error("callGemini failed:", e.message)
    throw e
  }
}

const QUICK_PROMPTS = [
  "Is it safe to travel alone tonight?",
  "Nearest police station to me",
  "I feel unsafe right now",
  "Safe areas in Chennai",
  "Tips for solo travel in TN",
  "Hotel safety checklist",
]

export default function ChatPage() {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 1, role: 'assistant',
      text: "Hello! I'm your SafeHer AI Assistant 💜\n\nI'm here to help you stay safe across Tamil Nadu — ask me about safety tips, nearby resources, travel advice, or get support during an emergency.\n\n**Emergency: 112 | Police: 100 | Women: 1091**",
      time: new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
    }
  ])
  const [input, setInput] = useState("")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [online, setOnline] = useState(true)
  const scrollRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const handleOnline = () => setOnline(true)
    const handleOffline = () => setOnline(false)
    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)
    setOnline(navigator.onLine)
    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [])

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' })
    }
  }, [messages, loading])

  const getTime = () => new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })

  const formatMessage = (text: string) => {
    // Convert **bold** and newlines to JSX
    return text.split('\n').map((line, i) => {
      const parts = line.split(/\*\*(.*?)\*\*/g)
      return (
        <span key={i}>
          {parts.map((part, j) =>
            j % 2 === 1 ? <strong key={j}>{part}</strong> : part
          )}
          {i < text.split('\n').length - 1 && <br />}
        </span>
      )
    })
  }

  const handleSend = useCallback(async (text?: string) => {
    const msgText = (text || input).trim()
    if (!msgText || loading) return

    setError(null)
    const userMsg: Message = { id: Date.now(), role: 'user', text: msgText, time: getTime() }
    setMessages(prev => [...prev, userMsg])
    setInput("")
    setLoading(true)

    // Build Gemini-format history from all messages
    const allMsgs = [...messages, userMsg]
    const geminiHistory = allMsgs.map(m => ({
      role: m.role === 'user' ? 'user' : 'model',
      parts: [{ text: m.text }]
    }))

    try {
      const reply = await callGemini(geminiHistory)
      setMessages(prev => [...prev, { id: Date.now() + 1, role: 'assistant', text: reply, time: getTime() }])
    } catch (e: any) {
      const fallback = FALLBACK_RESPONSES[Math.floor(Math.random() * FALLBACK_RESPONSES.length)]
      setMessages(prev => [...prev, { id: Date.now() + 1, role: 'assistant', text: fallback, time: getTime() }])
      if (!online) {
        setError("You appear to be offline. Emergency numbers work without internet.")
      }
    } finally {
      setLoading(false)
    }
  }, [input, loading, messages, online])

  return (
    <div className="h-screen md:pl-20 flex flex-col bg-background overflow-hidden">
      <Navigation />

      {/* Header */}
      <header className="px-4 py-3 bg-card border-b border-border flex items-center gap-3 shrink-0 shadow-sm">
        <Link href="/" className="md:hidden w-8 h-8 flex items-center justify-center rounded-lg hover:bg-muted transition-colors">
          <ChevronLeft className="w-5 h-5 text-muted-foreground" />
        </Link>
        <div className="w-10 h-10 rounded-xl flex items-center justify-center shadow-sm shrink-0"
          style={{background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'}}>
          <ShieldCheck className="w-5 h-5 text-white" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5">
            <h1 className="font-display font-black text-sm text-foreground">SafeHer AI</h1>
            <Sparkles className="w-3 h-3 text-primary" />
          </div>
          <div className="flex items-center gap-1.5 mt-0.5">
            <div className={`w-1.5 h-1.5 rounded-full ${online ? 'bg-emerald-500 animate-pulse' : 'bg-orange-500'}`} />
            <span className="text-[10px] text-muted-foreground font-semibold">
              {online ? 'Gemini AI · Tamil Nadu Safety' : 'Offline Mode'}
            </span>
            {!online && <WifiOff className="w-3 h-3 text-orange-500" />}
          </div>
        </div>
        <a href="tel:112">
          <button className="w-9 h-9 bg-red-100 dark:bg-red-950/40 rounded-xl flex items-center justify-center hover:bg-red-200 transition-colors">
            <Phone className="w-4 h-4 text-red-600" />
          </button>
        </a>
      </header>

      {/* Error banner */}
      {error && (
        <div className="mx-4 mt-2 p-3 bg-orange-50 dark:bg-orange-950/30 border border-orange-200 dark:border-orange-800/40 rounded-xl flex items-center gap-2 shrink-0">
          <WifiOff className="w-4 h-4 text-orange-600 shrink-0" />
          <p className="text-xs text-orange-700 dark:text-orange-400 flex-1">{error}</p>
          <button onClick={() => setError(null)}><span className="text-orange-500 text-xs font-bold">✕</span></button>
        </div>
      )}

      {/* Messages */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
        {messages.map((m) => (
          <div key={m.id} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'} gap-2.5`}>
            {m.role === 'assistant' && (
              <div className="w-8 h-8 rounded-xl flex items-center justify-center shrink-0 mt-auto shadow-sm"
                style={{background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'}}>
                <ShieldCheck className="w-4 h-4 text-white" />
              </div>
            )}
            <div className="max-w-[82%]">
              <div className={`px-4 py-3 rounded-2xl text-sm leading-relaxed shadow-sm ${
                m.role === 'user'
                  ? 'text-white rounded-br-sm'
                  : 'bg-card text-foreground border border-border/60 rounded-bl-sm'
              }`} style={m.role === 'user' ? {background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'} : {}}>
                {formatMessage(m.text)}
              </div>
              <p className={`text-[9px] mt-1 text-muted-foreground ${m.role === 'user' ? 'text-right' : 'text-left'}`}>
                {m.time}
              </p>
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex justify-start gap-2.5">
            <div className="w-8 h-8 rounded-xl flex items-center justify-center shrink-0"
              style={{background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'}}>
              <ShieldCheck className="w-4 h-4 text-white" />
            </div>
            <div className="bg-card border border-border/60 px-4 py-3.5 rounded-2xl rounded-bl-sm">
              <div className="flex gap-1.5 items-center">
                {[0, 150, 300].map(delay => (
                  <div key={delay} className="w-2 h-2 rounded-full bg-primary/50 animate-bounce" style={{ animationDelay: `${delay}ms` }} />
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Quick prompts — show only early in conversation */}
      {messages.length <= 3 && !loading && (
        <div className="px-4 pb-2 flex gap-2 overflow-x-auto scrollbar-hide shrink-0">
          {QUICK_PROMPTS.map(p => (
            <button key={p} onClick={() => handleSend(p)}
              className="shrink-0 text-[11px] font-bold border px-3 py-2 rounded-full hover:bg-primary/10 transition-colors whitespace-nowrap text-primary border-primary/30 bg-primary/5">
              {p}
            </button>
          ))}
        </div>
      )}

      {/* Input */}
      <div className="px-4 py-3 bg-card border-t border-border shrink-0 pb-safe" style={{paddingBottom: 'max(12px, env(safe-area-inset-bottom, 12px))'}}>
        <div className="mb-20 md:mb-0 flex items-center gap-2 bg-muted rounded-2xl px-4 py-2.5 border border-transparent focus-within:border-primary/30 transition-colors">
          <input
            ref={inputRef}
            className="flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground"
            placeholder="Ask about safety, resources, emergencies..."
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && !e.shiftKey && handleSend()}
            disabled={loading}
          />
          <button
            onClick={() => handleSend()}
            disabled={!input.trim() || loading}
            className="w-9 h-9 rounded-xl flex items-center justify-center disabled:opacity-40 transition-all active:scale-95 shrink-0 shadow-sm"
            style={{background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'}}>
            {loading ? <RefreshCw className="w-4 h-4 text-white animate-spin" /> : <Send className="w-4 h-4 text-white" />}
          </button>
        </div>
      </div>
    </div>
  )
}
