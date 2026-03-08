"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { Home, MessageCircle, Shield, Star, Users, Siren } from "lucide-react"
import { cn } from "@/lib/utils"

export function Navigation() {
  const pathname = usePathname()

  const navItems = [
    { name: "Home", href: "/", icon: Home },
    { name: "Chat", href: "/chat", icon: MessageCircle },
    { name: "Resources", href: "/nearby", icon: Shield },
    { name: "Hotels", href: "/hotels", icon: Star },
    { name: "Community", href: "/community", icon: Users },
  ]

  return (
    <>
      {/* Mobile Bottom Nav */}
      <nav className="fixed bottom-0 left-0 right-0 z-50 md:hidden bg-card/95 backdrop-blur-xl border-t border-border">
        <div className="flex items-center justify-around px-2 py-2 relative" style={{paddingBottom: 'max(0.5rem, env(safe-area-inset-bottom))'}}>
          {navItems.slice(0, 2).map((item) => {
            const Icon = item.icon
            const isActive = pathname === item.href
            return (
              <Link key={item.name} href={item.href}
                className={cn("flex flex-col items-center gap-0.5 p-2 rounded-xl transition-all min-w-[56px]",
                  isActive ? "text-primary" : "text-muted-foreground hover:text-primary"
                )}
              >
                <Icon className={cn("w-5 h-5", isActive && "scale-110")} />
                <span className="text-[9px] font-semibold tracking-wide">{item.name}</span>
              </Link>
            )
          })}

          <div className="flex flex-col items-center -mt-8">
            <Link href="/sos">
              <div className="relative">
                <div className="absolute inset-0 bg-red-500 rounded-full blur-lg opacity-40 sos-pulse" />
                <div className="relative w-16 h-16 bg-gradient-to-br from-red-500 to-red-700 rounded-full flex flex-col items-center justify-center shadow-xl border-4 border-background">
                  <Siren className="w-6 h-6 text-white" />
                  <span className="text-[8px] font-black text-white tracking-widest">SOS</span>
                </div>
              </div>
            </Link>
            <span className="text-[9px] font-semibold text-red-500 mt-1">Emergency</span>
          </div>

          {navItems.slice(2).map((item) => {
            const Icon = item.icon
            const isActive = pathname === item.href
            return (
              <Link key={item.name} href={item.href}
                className={cn("flex flex-col items-center gap-0.5 p-2 rounded-xl transition-all min-w-[56px]",
                  isActive ? "text-primary" : "text-muted-foreground hover:text-primary"
                )}
              >
                <Icon className={cn("w-5 h-5", isActive && "scale-110")} />
                <span className="text-[9px] font-semibold tracking-wide">{item.name}</span>
              </Link>
            )
          })}
        </div>
      </nav>

      {/* Desktop Side Nav */}
      <nav className="hidden md:flex fixed left-0 top-0 bottom-0 z-50 w-20 flex-col items-center bg-card border-r border-border py-8 gap-2">
        <Link href="/" className="mb-6">
          <div className="w-10 h-10 bg-gradient-to-br from-primary to-accent rounded-xl flex items-center justify-center shadow-lg">
            <Shield className="w-5 h-5 text-white" />
          </div>
        </Link>
        {navItems.map((item) => {
          const Icon = item.icon
          const isActive = pathname === item.href
          return (
            <Link key={item.name} href={item.href}
              className={cn("flex flex-col items-center gap-1 p-3 rounded-xl w-14 transition-all",
                isActive ? "bg-primary/10 text-primary" : "text-muted-foreground hover:text-primary hover:bg-primary/5"
              )}
            >
              <Icon className="w-5 h-5" />
              <span className="text-[9px] font-semibold">{item.name}</span>
            </Link>
          )
        })}
        <div className="mt-auto">
          <Link href="/sos">
            <div className="relative">
              <div className="absolute inset-0 bg-red-500 rounded-xl blur opacity-30 sos-pulse" />
              <div className="relative w-14 h-14 bg-gradient-to-br from-red-500 to-red-700 rounded-xl flex flex-col items-center justify-center shadow-lg">
                <Siren className="w-5 h-5 text-white" />
                <span className="text-[8px] font-black text-white tracking-wider">SOS</span>
              </div>
            </div>
          </Link>
        </div>
      </nav>
    </>
  )
}
