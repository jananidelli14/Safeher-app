"use client"

import { Navigation } from "@/components/Navigation"
import { Shield, MapPin, Siren, Hotel, MessageSquare, ArrowRight, Users, Phone, Bell, ChevronRight, Star, ShieldCheck, AlertTriangle, Pill, Zap, Heart, Navigation2, Clock } from "lucide-react"
import Link from "next/link"
import { useState, useEffect } from "react"

export default function Home() {
  const [time, setTime] = useState("")
  const [locationName, setLocationName] = useState("Tamil Nadu")
  const hour = new Date().getHours()
  const greeting = hour < 5 ? "Stay Safe Tonight" : hour < 12 ? "Good Morning" : hour < 17 ? "Good Afternoon" : "Good Evening"
  const greetingEmoji = hour < 5 ? "🌙" : hour < 12 ? "🌅" : hour < 17 ? "☀️" : "🌆"

  useEffect(() => {
    const updateTime = () => setTime(new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true }))
    updateTime()
    const interval = setInterval(updateTime, 1000)
    return () => clearInterval(interval)
  }, [])

  useEffect(() => {
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          fetch(`https://nominatim.openstreetmap.org/reverse?lat=${pos.coords.latitude}&lon=${pos.coords.longitude}&format=json`)
            .then(r => r.json())
            .then(d => setLocationName(d.address?.suburb || d.address?.city_district || d.address?.city || "Tamil Nadu"))
            .catch(() => setLocationName("Tamil Nadu"))
        },
        () => setLocationName("Tamil Nadu")
      )
    }
  }, [])

  const stats = [
    { icon: Shield, label: "Police", value: "3", color: "from-blue-500 to-blue-700", href: "/nearby", bg: "bg-blue-500/10 text-blue-600" },
    { icon: Heart, label: "Hospitals", value: "5", color: "from-red-400 to-rose-600", href: "/nearby", bg: "bg-red-500/10 text-red-600" },
    { icon: Pill, label: "Pharmacy", value: "8", color: "from-emerald-500 to-teal-600", href: "/nearby", bg: "bg-emerald-500/10 text-emerald-600" },
    { icon: Hotel, label: "Safe Hotels", value: "12", color: "from-amber-500 to-orange-600", href: "/hotels", bg: "bg-amber-500/10 text-amber-600" },
  ]

  const features = [
    { icon: MessageSquare, title: "AI Safety Chat", desc: "24/7 Gemini-powered safety guidance", href: "/chat", from: "from-violet-600", to: "to-purple-700", accent: "violet" },
    { icon: MapPin, title: "Safety Map", desc: "Live safe zones & resource locator", href: "/nearby", from: "from-sky-500", to: "to-blue-600", accent: "sky" },
    { icon: Users, title: "Community", desc: "Real safety experiences from women", href: "/community", from: "from-pink-500", to: "to-rose-600", accent: "pink" },
    { icon: Star, title: "Safe Hotels", desc: "AI-vetted women-friendly stays", href: "/hotels", from: "from-amber-500", to: "to-orange-600", accent: "amber" },
  ]

  const emergency = [
    { name: "Police", number: "100", color: "text-blue-700 dark:text-blue-400", ring: "ring-blue-200 dark:ring-blue-800", bg: "bg-blue-50 dark:bg-blue-950/40" },
    { name: "Emergency", number: "112", color: "text-red-700 dark:text-red-400", ring: "ring-red-200 dark:ring-red-800", bg: "bg-red-50 dark:bg-red-950/40" },
    { name: "Women", number: "1091", color: "text-purple-700 dark:text-purple-400", ring: "ring-purple-200 dark:ring-purple-800", bg: "bg-purple-50 dark:bg-purple-950/40" },
    { name: "Ambulance", number: "108", color: "text-emerald-700 dark:text-emerald-400", ring: "ring-emerald-200 dark:ring-emerald-800", bg: "bg-emerald-50 dark:bg-emerald-950/40" },
  ]

  return (
    <div className="min-h-screen md:pl-20 pb-28 md:pb-8" style={{background: 'hsl(var(--background))'}}>
      <Navigation />

      {/* Decorative top gradient */}
      <div className="fixed top-0 left-0 right-0 h-72 pointer-events-none" style={{
        background: 'radial-gradient(ellipse 80% 60% at 50% -20%, hsl(262 83% 58% / 0.12) 0%, transparent 70%)',
        zIndex: 0
      }} />

      <main className="relative max-w-2xl mx-auto px-4 pt-6 space-y-5" style={{zIndex: 1}}>

        {/* ── HEADER ── */}
        <header className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-1.5 mb-1">
              <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-[11px] font-bold text-emerald-600 dark:text-emerald-400 tracking-widest uppercase">Shield Active</span>
            </div>
            <h1 className="text-[1.65rem] font-display font-black text-foreground leading-none tracking-tight">
              {greeting} {greetingEmoji}
            </h1>
            <div className="flex items-center gap-1.5 mt-1.5">
              <MapPin className="w-3.5 h-3.5 text-primary" />
              <span className="text-sm text-muted-foreground font-medium">{locationName}</span>
            </div>
          </div>
          <div className="flex items-center gap-2.5">
            <button className="relative w-10 h-10 bg-card border border-border/60 rounded-xl flex items-center justify-center shadow-sm hover:shadow-md transition-shadow">
              <Bell className="w-4.5 h-4.5 text-muted-foreground" />
              <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full shadow-sm" />
            </button>
            <div className="w-10 h-10 rounded-xl flex items-center justify-center font-black text-sm text-white shadow-lg" style={{background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'}}>
              S
            </div>
          </div>
        </header>

        {/* ── HERO SHIELD CARD ── */}
        <div className="relative overflow-hidden rounded-3xl p-6 shadow-2xl" style={{
          background: 'linear-gradient(135deg, hsl(262 83% 40%) 0%, hsl(262 83% 28%) 50%, hsl(240 70% 20%) 100%)'
        }}>
          {/* Mesh pattern */}
          <div className="absolute inset-0 opacity-20" style={{
            backgroundImage: 'radial-gradient(circle at 20% 50%, hsl(280 100% 80%) 0%, transparent 40%), radial-gradient(circle at 80% 20%, hsl(220 100% 70%) 0%, transparent 40%)'
          }} />
          <div className="absolute top-0 right-0 w-48 h-48 rounded-full opacity-10" style={{background: 'radial-gradient(circle, white, transparent)', transform: 'translate(30%, -30%)'}} />

          <div className="relative flex items-center justify-between">
            <div className="flex-1">
              <div className="inline-flex items-center gap-2 bg-white/15 backdrop-blur-sm rounded-full px-3 py-1 mb-4">
                <div className="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse" />
                <span className="text-white/90 text-[11px] font-bold tracking-wider uppercase">Live Monitoring</span>
              </div>
              <h2 className="text-2xl font-display font-black text-white leading-tight">
                You're Protected<br />
                <span className="text-white/60 text-lg font-semibold">Across Tamil Nadu</span>
              </h2>
              <p className="text-white/50 text-sm mt-2 leading-relaxed">
                SafeHer shield is watching over your journey
              </p>
            </div>
            {/* Animated shield */}
            <div className="shrink-0 ml-4">
              <div className="relative w-[88px] h-[88px]">
                <div className="absolute inset-0 rounded-2xl animate-ping opacity-20" style={{background: 'linear-gradient(135deg, hsl(262 83% 70%), hsl(300 70% 60%))'}} />
                <div className="relative w-full h-full rounded-2xl border border-white/20 flex items-center justify-center shadow-2xl" style={{background: 'linear-gradient(135deg, rgba(255,255,255,0.2), rgba(255,255,255,0.05))', backdropFilter: 'blur(10px)'}}>
                  <Shield className="w-10 h-10 text-white" />
                </div>
              </div>
            </div>
          </div>

          {/* Bottom stat row */}
          <div className="relative mt-5 pt-4 border-t border-white/10 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Clock className="w-3.5 h-3.5 text-white/40" />
              <span className="text-white/40 text-xs">Current Time</span>
            </div>
            <span className="text-white font-display font-black text-xl tracking-[0.12em]">{time}</span>
          </div>
        </div>

        {/* ── SOS CARD ── */}
        <div className="relative overflow-hidden rounded-3xl border-2 border-red-200/60 dark:border-red-900/40 p-5" style={{
          background: 'linear-gradient(135deg, hsl(0 80% 97%) 0%, hsl(0 80% 94%) 100%)',
        }}>
          <style>{`@media (prefers-color-scheme: dark) { .sos-card { background: linear-gradient(135deg, hsl(0 50% 10%) 0%, hsl(0 40% 8%) 100%) !important; }}`}</style>
          <div className="dark:hidden absolute inset-0 rounded-3xl" style={{background: 'linear-gradient(135deg, #fff1f2 0%, #ffe4e6 100%)'}} />
          <div className="hidden dark:block absolute inset-0 rounded-3xl" style={{background: 'linear-gradient(135deg, hsl(0 50% 10%) 0%, hsl(0 40% 8%) 100%)'}} />

          <div className="relative flex items-center gap-5">
            {/* SOS Button */}
            <Link href="/sos" className="shrink-0">
              <div className="relative">
                <div className="absolute inset-0 rounded-full animate-ping opacity-25" style={{background: 'radial-gradient(circle, #ef4444, transparent)'}} />
                <div className="relative w-[88px] h-[88px] rounded-full border-4 border-white dark:border-red-950 shadow-2xl flex flex-col items-center justify-center text-white active:scale-95 transition-transform cursor-pointer"
                  style={{background: 'linear-gradient(135deg, #ef4444, #b91c1c)'}}>
                  <Siren className="w-7 h-7 mb-0.5" />
                  <span className="text-[11px] font-black tracking-[0.3em]">SOS</span>
                </div>
              </div>
            </Link>

            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <Zap className="w-4 h-4 text-red-600 dark:text-red-400" />
                <h3 className="font-display font-black text-red-700 dark:text-red-400 text-base">Emergency SOS</h3>
              </div>
              <p className="text-red-600/70 dark:text-red-400/60 text-xs leading-relaxed">
                Instantly alerts TN Police, emergency contacts & SafeHer community
              </p>
              <Link href="/sos">
                <button className="mt-3 text-white text-xs font-black px-5 py-2 rounded-full transition-all shadow-lg active:scale-95"
                  style={{background: 'linear-gradient(135deg, #ef4444, #b91c1c)', boxShadow: '0 4px 15px rgba(239,68,68,0.4)'}}>
                  Hold to Activate →
                </button>
              </Link>
            </div>
          </div>
        </div>

        {/* ── NEARBY RESOURCES ── */}
        <section>
          <div className="flex items-center justify-between mb-3">
            <div>
              <h2 className="font-display font-black text-foreground text-lg leading-none">Nearby Resources</h2>
              <p className="text-muted-foreground text-xs mt-0.5">Around {locationName}</p>
            </div>
            <Link href="/nearby" className="flex items-center gap-1 text-xs font-bold text-primary bg-primary/10 px-3 py-1.5 rounded-full hover:bg-primary/15 transition-colors">
              View All <ArrowRight className="w-3 h-3" />
            </Link>
          </div>
          <div className="grid grid-cols-4 gap-2.5">
            {stats.map((s) => (
              <Link key={s.label} href={s.href}>
                <div className="relative overflow-hidden rounded-2xl p-3.5 flex flex-col items-center gap-2 cursor-pointer active:scale-95 transition-transform shadow-sm hover:shadow-md"
                  style={{background: `linear-gradient(135deg, hsl(var(--card)), hsl(var(--card)))`}}
                  className="relative overflow-hidden rounded-2xl p-3.5 flex flex-col items-center gap-2 cursor-pointer active:scale-95 transition-transform shadow-sm hover:shadow-md bg-card border border-border/60">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center bg-gradient-to-br ${s.color}`}>
                    <s.icon className="w-5 h-5 text-white" />
                  </div>
                  <div className="text-center">
                    <p className="text-xl font-display font-black text-foreground leading-none">{s.value}</p>
                    <p className="text-[10px] font-semibold text-muted-foreground mt-0.5 leading-tight">{s.label}</p>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </section>

        {/* ── FEATURES GRID ── */}
        <section>
          <h2 className="font-display font-black text-foreground text-lg mb-3">Safety Features</h2>
          <div className="grid grid-cols-2 gap-3">
            {features.map((feat) => (
              <Link key={feat.title} href={feat.href}>
                <div className="group relative overflow-hidden rounded-2xl p-4 bg-card border border-border/60 hover:border-primary/30 hover:shadow-lg transition-all cursor-pointer active:scale-[0.98]">
                  <div className={`w-11 h-11 rounded-xl flex items-center justify-center mb-3 bg-gradient-to-br ${feat.from} ${feat.to} shadow-lg`}>
                    <feat.icon className="w-5 h-5 text-white" />
                  </div>
                  <h3 className="font-display font-black text-foreground text-sm leading-none">{feat.title}</h3>
                  <p className="text-muted-foreground text-[11px] mt-1 leading-relaxed">{feat.desc}</p>
                  <div className="absolute bottom-3 right-3 opacity-0 group-hover:opacity-100 transition-opacity">
                    <ChevronRight className="w-4 h-4 text-primary" />
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </section>

        {/* ── QUICK DIAL ── */}
        <section>
          <h2 className="font-display font-black text-foreground text-lg mb-3">Quick Dial</h2>
          <div className="grid grid-cols-4 gap-2.5">
            {emergency.map((em) => (
              <a key={em.name} href={`tel:${em.number}`}>
                <div className={`${em.bg} ring-1 ${em.ring} rounded-2xl p-3 flex flex-col items-center gap-1.5 active:scale-95 transition-transform cursor-pointer`}>
                  <div className="w-9 h-9 bg-white dark:bg-background/50 rounded-xl flex items-center justify-center shadow-sm">
                    <Phone className={`w-4 h-4 ${em.color}`} />
                  </div>
                  <span className={`text-xl font-display font-black ${em.color} leading-none`}>{em.number}</span>
                  <span className="text-[9px] font-bold text-muted-foreground text-center leading-tight">{em.name}</span>
                </div>
              </a>
            ))}
          </div>
        </section>

        {/* ── SAFETY TIP BANNER ── */}
        <div className="rounded-2xl p-4 flex items-start gap-3.5 border border-primary/20"
          style={{background: 'linear-gradient(135deg, hsl(262 83% 58% / 0.08), hsl(262 83% 58% / 0.03))'}}>
          <div className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0" style={{background: 'hsl(262 83% 58% / 0.15)'}}>
            <ShieldCheck className="w-4.5 h-4.5 text-primary" />
          </div>
          <div>
            <p className="text-[11px] font-black text-primary uppercase tracking-widest mb-1">Safety Tip of the Day</p>
            <p className="text-sm text-foreground/75 leading-relaxed">
              Use <strong className="text-foreground">Kavalan-SOS (112)</strong> for fastest response in Tamil Nadu. Share your live location with a trusted contact before solo travel.
            </p>
          </div>
        </div>

        {/* ── COMMUNITY PREVIEW ── */}
        <div className="rounded-2xl p-4 border border-border/60 bg-card">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-pink-500 to-rose-600 flex items-center justify-center">
                <Users className="w-4 h-4 text-white" />
              </div>
              <div>
                <p className="font-display font-black text-sm text-foreground">Community Feed</p>
                <p className="text-[10px] text-muted-foreground">Latest safety updates</p>
              </div>
            </div>
            <Link href="/community" className="text-[11px] font-bold text-primary">View All →</Link>
          </div>
          <div className="space-y-2.5">
            {[
              { loc: "Marina Beach", msg: "Police patrol visible — safe till 10pm 🟢", time: "2h ago" },
              { loc: "T Nagar Metro", msg: "Well-lit area, security present at all exits 🟢", time: "4h ago" },
              { loc: "Egmore Station", msg: "Avoid west exit after 11pm ⚠️", time: "6h ago" },
            ].map((item, i) => (
              <div key={i} className="flex items-start gap-3 p-2.5 rounded-xl bg-muted/40">
                <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center shrink-0 text-xs font-black text-primary">
                  {item.loc[0]}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-bold text-foreground">{item.loc}</p>
                  <p className="text-[11px] text-muted-foreground mt-0.5 leading-tight">{item.msg}</p>
                </div>
                <span className="text-[10px] text-muted-foreground shrink-0">{item.time}</span>
              </div>
            ))}
          </div>
        </div>

      </main>
    </div>
  )
}
