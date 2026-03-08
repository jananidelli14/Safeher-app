"use client"

import { Navigation } from "@/components/Navigation"
import { Shield, MapPin, Phone, ExternalLink, ChevronLeft, AlertCircle, Hospital, Pill } from "lucide-react"
import Link from "next/link"
import { useState } from "react"

const RESOURCES = {
  police: [
    { name: "Greater Chennai Police", address: "Vepery High Road, Chennai", distance: "0.8 km", phone: "100", rating: 4.8 },
    { name: "K5 Peravallur Station", address: "Jawahar Nagar, Chennai", distance: "2.5 km", phone: "044 2345 2641", rating: 4.5 },
    { name: "B1 Madurai Town Police", address: "Simmakkal, Madurai", distance: "1.5 km", phone: "0452 234 6500", rating: 4.6 },
    { name: "Women's Safety Wing TN", address: "Commissioner Office, Chennai", distance: "3.2 km", phone: "044 2538 4000", rating: 4.9 },
  ],
  hospitals: [
    { name: "Apollo Hospitals", address: "Greams Lane, Off Greams Road, Chennai", distance: "1.2 km", phone: "044 2829 3333", rating: 4.7 },
    { name: "MIOT International", address: "Mount Poonamallee Road, Chennai", distance: "5.4 km", phone: "044 4222 6000", rating: 4.6 },
    { name: "Madurai Medical College", address: "Panagal Rd, Alwarpuram, Madurai", distance: "2.1 km", phone: "0452 253 2531", rating: 4.4 },
    { name: "Fortis Malar Hospital", address: "Gandhi Nagar, Adyar, Chennai", distance: "4.0 km", phone: "044 4289 2222", rating: 4.5 },
    { name: "Sri Ramachandra Hospital", address: "Porur, Chennai", distance: "6.1 km", phone: "044 4592 8600", rating: 4.8 },
  ],
  pharmacies: [
    { name: "MedPlus Pharmacy", address: "Anna Nagar, Chennai", distance: "0.5 km", phone: "1860 200 3000", rating: 4.3 },
    { name: "Apollo Pharmacy", address: "T Nagar, Chennai", distance: "1.1 km", phone: "1860 500 0101", rating: 4.5 },
    { name: "Wellness Forever", address: "Velachery, Chennai", distance: "2.3 km", phone: "044 2244 5566", rating: 4.2 },
  ]
}

type Tab = 'police' | 'hospitals' | 'pharmacies'

function ResourceCard({ item, type }: { item: any, type: Tab }) {
  const colors = {
    police: "bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400",
    hospitals: "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400",
    pharmacies: "bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400",
  }

  const icons = {
    police: <Shield className="w-5 h-5" />,
    hospitals: <Hospital className="w-5 h-5" />,
    pharmacies: <Pill className="w-5 h-5" />,
  }

  const distColors = {
    police: "text-blue-600 bg-blue-50 dark:bg-blue-900/20",
    hospitals: "text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20",
    pharmacies: "text-orange-600 bg-orange-50 dark:bg-orange-900/20",
  }

  return (
    <div className="bg-card border border-border rounded-2xl p-5 card-hover">
      <div className="flex items-start gap-4">
        <div className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${colors[type]}`}>
          {icons[type]}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2">
            <h3 className="font-display font-bold text-sm text-foreground leading-tight">{item.name}</h3>
            <span className={`text-[10px] font-bold px-2 py-1 rounded-full shrink-0 ${distColors[type]}`}>
              {item.distance}
            </span>
          </div>
          <div className="flex items-center gap-1 mt-1">
            <MapPin className="w-3 h-3 text-muted-foreground shrink-0" />
            <p className="text-xs text-muted-foreground truncate">{item.address}</p>
          </div>
          <div className="flex gap-2 mt-3">
            <a href={`tel:${item.phone}`} className="flex-1">
              <button className="w-full flex items-center justify-center gap-1.5 bg-muted hover:bg-muted/80 text-foreground text-xs font-bold py-2 rounded-xl transition-colors">
                <Phone className="w-3.5 h-3.5" /> {item.phone}
              </button>
            </a>
            <button className="flex items-center justify-center gap-1.5 bg-primary text-white text-xs font-bold py-2 px-4 rounded-xl hover:bg-primary/90 transition-colors">
              <ExternalLink className="w-3.5 h-3.5" /> Navigate
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default function NearbyResourcesPage() {
  const [activeTab, setActiveTab] = useState<Tab>('police')

  const tabs = [
    { key: 'police' as Tab, label: 'TN Police', count: RESOURCES.police.length, icon: <Shield className="w-4 h-4" />, color: "from-blue-500 to-blue-700" },
    { key: 'hospitals' as Tab, label: 'Hospitals', count: RESOURCES.hospitals.length, icon: <Hospital className="w-4 h-4" />, color: "from-emerald-500 to-emerald-700" },
    { key: 'pharmacies' as Tab, label: 'Pharmacies', count: RESOURCES.pharmacies.length, icon: <Pill className="w-4 h-4" />, color: "from-orange-500 to-orange-600" },
  ]

  return (
    <div className="min-h-screen md:pl-20 pb-28 md:pb-8 mesh-bg">
      <Navigation />
      <main className="max-w-2xl mx-auto px-4 pt-6 space-y-6">
        <header>
          <Link href="/" className="inline-flex items-center text-muted-foreground hover:text-foreground text-sm mb-3 transition-colors">
            <ChevronLeft className="w-4 h-4 mr-1" /> Dashboard
          </Link>
          <h1 className="text-2xl font-display font-bold">Tamil Nadu Resources</h1>
          <p className="text-muted-foreground text-sm mt-0.5">Quick access to police, hospitals & pharmacies near you</p>
        </header>

        {/* Emergency Banner */}
        <div className="bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800/40 rounded-2xl p-4 flex items-center gap-3">
          <div className="w-10 h-10 bg-red-100 dark:bg-red-900/30 rounded-xl flex items-center justify-center shrink-0">
            <AlertCircle className="w-5 h-5 text-red-600" />
          </div>
          <div className="flex-1">
            <p className="font-display font-bold text-red-700 dark:text-red-400 text-sm">In Emergency?</p>
            <p className="text-xs text-red-600/70 dark:text-red-400/70">Call 112 immediately or use the SOS button</p>
          </div>
          <a href="tel:112">
            <button className="bg-red-600 text-white text-xs font-bold px-4 py-2 rounded-xl hover:bg-red-700 transition-colors">
              Call 112
            </button>
          </a>
        </div>

        {/* Tab Cards */}
        <div className="grid grid-cols-3 gap-3">
          {tabs.map(tab => (
            <button key={tab.key} onClick={() => setActiveTab(tab.key)}
              className={`relative overflow-hidden rounded-2xl p-4 text-left transition-all ${
                activeTab === tab.key
                  ? `bg-gradient-to-br ${tab.color} text-white shadow-lg`
                  : 'bg-card border border-border text-muted-foreground hover:border-primary/30'
              }`}
            >
              <div className={activeTab === tab.key ? 'text-white' : ''}>{tab.icon}</div>
              <p className="text-xl font-display font-bold mt-2">{tab.count}</p>
              <p className={`text-[10px] font-bold ${activeTab === tab.key ? 'text-white/80' : 'text-muted-foreground'}`}>
                {tab.label}
              </p>
            </button>
          ))}
        </div>

        {/* Resources List */}
        <div className="space-y-3">
          {RESOURCES[activeTab].map((item, i) => (
            <ResourceCard key={i} item={item} type={activeTab} />
          ))}
        </div>
      </main>
    </div>
  )
}
