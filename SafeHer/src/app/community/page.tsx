"use client"

import { Navigation } from "@/components/Navigation"
import { MapPin, MessageSquare, ThumbsUp, ShieldCheck, AlertTriangle, Users, Plus, Star, Info, CheckCircle2, Filter, Flame, TrendingUp, X } from "lucide-react"
import Link from "next/link"
import { useState } from "react"
import { useToast } from "@/hooks/use-toast"

type PostType = 'safe' | 'warning' | 'tip' | 'insight'

type Post = {
  id: number
  user: string
  avatar: string
  location: string
  content: string
  type: PostType
  time: string
  likes: number
  comments: number
  verified?: boolean
  rating?: number
  liked?: boolean
}

const SEEDED_POSTS: Post[] = [
  {
    id: 1001, user: "Tourist Review", avatar: "T", location: "Marina Beach, Chennai",
    content: "Visited Marina Beach late evening. Area was well lit and police patrol was visible. Felt safe walking around with family. The beach stretch has good lighting and refreshment stalls open till 10pm.",
    type: 'safe', time: "2 hours ago", likes: 47, comments: 8, verified: true, rating: 5
  },
  {
    id: 1002, user: "Traveler Feedback", avatar: "V", location: "T Nagar Shopping District",
    content: "Crowded but safe area. Lots of shops open late and security guards around. As a solo woman traveler I felt comfortable here even past 9pm. Metro connectivity makes it very accessible.",
    type: 'safe', time: "5 hours ago", likes: 31, comments: 5, verified: true, rating: 4
  },
  {
    id: 1003, user: "Travel Tip", avatar: "E", location: "Egmore Railway Station",
    content: "Good transport hub but best to avoid isolated areas late at night. The women-only waiting room on platform 1 is clean and well-maintained. Pre-book your tickets to avoid long queues.",
    type: 'tip', time: "1 day ago", likes: 62, comments: 12, verified: true, rating: 3
  },
  {
    id: 1004, user: "Priya S.", avatar: "P", location: "Pondy Bazaar, Chennai",
    content: "Great place to shop! Always crowded which makes it feel safe. CCTV cameras visible everywhere. Autorickshaw stand nearby is well-regulated. Perfect for solo evening outings.",
    type: 'safe', time: "3 hours ago", likes: 28, comments: 4, rating: 4
  },
  {
    id: 1005, user: "Anitha R.", avatar: "A", location: "Madurai Junction",
    content: "Be careful at the west exit late at night. The lighting is a bit dim and there are fewer people. The main entrance and platform area is fine with good police presence. Take pre-paid autos.",
    type: 'warning', time: "6 hours ago", likes: 53, comments: 9, rating: 2
  },
  {
    id: 1006, user: "Lakshmi K.", avatar: "L", location: "Coimbatore Omni Bus Stand",
    content: "Women's waiting room is clean and well-guarded. Great facility for solo travelers. Lockers available. Staff is helpful. Pre-paid auto service available outside. Highly recommend.",
    type: 'safe', time: "1 day ago", likes: 41, comments: 7, rating: 5
  },
  {
    id: 1007, user: "Travel Tip", avatar: "M", location: "Mahabalipuram Beach",
    content: "Beautiful heritage site — best visited before 6pm. Avoid isolated monument areas after dark. The main beach road is well-lit with shops open until 9pm. Carry water and a power bank.",
    type: 'tip', time: "2 days ago", likes: 38, comments: 6, verified: true, rating: 3
  },
  {
    id: 1008, user: "Kavya M.", avatar: "K", location: "Anna Nagar, Chennai",
    content: "Residential area that feels very safe. Good street lighting, regular police patrols. Lots of cafes and restaurants open late. Well connected by metro. Great for solo women travelers.",
    type: 'safe', time: "4 hours ago", likes: 19, comments: 3, rating: 5
  },
  {
    id: 1009, user: "Meera J.", avatar: "M", location: "Nungambakkam, Chennai",
    content: "This area near the consulates has heavy security presence. Very safe even at late hours. Multiple hotels and restaurants. Well-lit roads and frequent patrolling.",
    type: 'safe', time: "8 hours ago", likes: 23, comments: 2, rating: 5
  },
  {
    id: 1010, user: "Safety Alert", avatar: "S", location: "Koyambedu Bus Terminus",
    content: "Avoid the far parking lot after 9pm — poor lighting. The main terminus area is fine with CCTV and security. Women's helpdesk is open 24/7 at Gate 3. Use official pre-paid auto.",
    type: 'warning', time: "12 hours ago", likes: 71, comments: 15, verified: true, rating: 2
  }
]

const TYPE_CONFIG = {
  safe: {
    badge: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950/50 dark:text-emerald-400",
    icon: ShieldCheck,
    label: "Safe Zone",
    dot: "bg-emerald-500",
    border: "border-l-emerald-500"
  },
  warning: {
    badge: "bg-orange-100 text-orange-700 dark:bg-orange-950/50 dark:text-orange-400",
    icon: AlertTriangle,
    label: "Stay Alert",
    dot: "bg-orange-500",
    border: "border-l-orange-500"
  },
  tip: {
    badge: "bg-sky-100 text-sky-700 dark:bg-sky-950/50 dark:text-sky-400",
    icon: Info,
    label: "Travel Tip",
    dot: "bg-sky-500",
    border: "border-l-sky-500"
  },
  insight: {
    badge: "bg-violet-100 text-violet-700 dark:bg-violet-950/50 dark:text-violet-400",
    icon: Star,
    label: "Insight",
    dot: "bg-violet-500",
    border: "border-l-violet-500"
  }
}

const AVATAR_COLORS = [
  "from-violet-500 to-purple-600",
  "from-pink-500 to-rose-600",
  "from-sky-500 to-blue-600",
  "from-emerald-500 to-teal-600",
  "from-amber-500 to-orange-600",
]

function PostCard({ post, onLike }: { post: Post, onLike: (id: number) => void }) {
  const cfg = TYPE_CONFIG[post.type]
  const TypeIcon = cfg.icon
  const colorIdx = post.id % AVATAR_COLORS.length

  return (
    <div className={`bg-card border border-border/60 border-l-4 ${cfg.border} rounded-2xl p-4 transition-all hover:shadow-md`}>
      {/* Header */}
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="flex items-center gap-2.5">
          <div className={`w-9 h-9 rounded-xl bg-gradient-to-br ${AVATAR_COLORS[colorIdx]} flex items-center justify-center text-white font-black text-sm shrink-0`}>
            {post.avatar}
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="text-sm font-bold text-foreground">{post.user}</span>
              {post.verified && (
                <CheckCircle2 className="w-3.5 h-3.5 text-primary" />
              )}
            </div>
            <div className="flex items-center gap-1 mt-0.5">
              <MapPin className="w-2.5 h-2.5 text-muted-foreground" />
              <span className="text-[10px] text-muted-foreground font-medium">{post.location}</span>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-1.5 shrink-0">
          <span className={`inline-flex items-center gap-1 text-[10px] font-bold px-2 py-1 rounded-full ${cfg.badge}`}>
            <TypeIcon className="w-2.5 h-2.5" />
            {cfg.label}
          </span>
        </div>
      </div>

      {/* Verified badge */}
      {post.verified && (
        <div className="mb-2 inline-flex items-center gap-1.5 bg-primary/8 border border-primary/20 rounded-lg px-2.5 py-1">
          <ShieldCheck className="w-3 h-3 text-primary" />
          <span className="text-[10px] font-bold text-primary">Verified Travel Insight</span>
        </div>
      )}

      {/* Content */}
      <p className="text-sm text-foreground/85 leading-relaxed mb-3">{post.content}</p>

      {/* Rating */}
      {post.rating && (
        <div className="flex items-center gap-1 mb-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Star key={i} className={`w-3.5 h-3.5 ${i < post.rating! ? 'text-amber-400 fill-amber-400' : 'text-muted-foreground/30'}`} />
          ))}
          <span className="text-[10px] text-muted-foreground ml-1 font-semibold">Safety Rating</span>
        </div>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between pt-2.5 border-t border-border/50">
        <span className="text-[10px] text-muted-foreground">{post.time}</span>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground transition-colors">
            <MessageSquare className="w-3.5 h-3.5" />
            <span className="text-[11px] font-semibold">{post.comments}</span>
          </button>
          <button
            onClick={() => onLike(post.id)}
            className={`flex items-center gap-1.5 transition-colors ${post.liked ? 'text-primary' : 'text-muted-foreground hover:text-primary'}`}
          >
            <ThumbsUp className={`w-3.5 h-3.5 ${post.liked ? 'fill-current' : ''}`} />
            <span className="text-[11px] font-bold">{post.likes}</span>
          </button>
        </div>
      </div>
    </div>
  )
}

export default function CommunityPage() {
  const [posts, setPosts] = useState<Post[]>(SEEDED_POSTS)
  const [filter, setFilter] = useState<'all' | 'safe' | 'warning' | 'tip' | 'verified'>('all')
  const [showForm, setShowForm] = useState(false)
  const [newPost, setNewPost] = useState({ location: "", content: "", type: 'safe' as PostType })
  const { toast } = useToast()

  const filtered = filter === 'all' ? posts
    : filter === 'verified' ? posts.filter(p => p.verified)
    : posts.filter(p => p.type === filter)

  const handleLike = (id: number) => {
    setPosts(prev => prev.map(p =>
      p.id === id ? { ...p, liked: !p.liked, likes: p.liked ? p.likes - 1 : p.likes + 1 } : p
    ))
  }

  const handlePost = () => {
    if (!newPost.location.trim() || !newPost.content.trim()) {
      toast({ title: "Please fill in all fields", variant: "destructive" })
      return
    }
    const post: Post = {
      id: Date.now(), user: "You", avatar: "Y",
      location: newPost.location, content: newPost.content,
      type: newPost.type, time: "Just now", likes: 0, comments: 0
    }
    setPosts(prev => [post, ...prev])
    setNewPost({ location: "", content: "", type: 'safe' })
    setShowForm(false)
    toast({ title: "✅ Posted!", description: "Your safety insight has been shared with the community." })
  }

  const filterTabs = [
    { key: 'all', label: 'All', icon: Users },
    { key: 'safe', label: 'Safe Zones', icon: ShieldCheck },
    { key: 'warning', label: 'Alerts', icon: AlertTriangle },
    { key: 'tip', label: 'Tips', icon: Info },
    { key: 'verified', label: 'Verified', icon: CheckCircle2 },
  ] as const

  return (
    <div className="min-h-screen md:pl-20 pb-28 md:pb-8 bg-background">
      <Navigation />

      <main className="max-w-2xl mx-auto px-4 pt-6 space-y-5">

        {/* Header */}
        <header className="flex items-start justify-between">
          <div>
            <h1 className="text-2xl font-display font-black text-foreground">Community</h1>
            <p className="text-sm text-muted-foreground mt-0.5">Real safety insights from women travelers</p>
          </div>
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-1.5 text-white text-sm font-bold px-4 py-2 rounded-xl shadow-lg active:scale-95 transition-transform"
            style={{background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'}}
          >
            <Plus className="w-4 h-4" /> Share
          </button>
        </header>

        {/* Stats Banner */}
        <div className="rounded-2xl p-4 flex items-center justify-around"
          style={{background: 'linear-gradient(135deg, hsl(262 83% 58% / 0.1), hsl(262 83% 58% / 0.04))', border: '1px solid hsl(262 83% 58% / 0.2)'}}>
          <div className="text-center">
            <p className="text-2xl font-display font-black text-foreground">{posts.length}</p>
            <p className="text-[10px] font-bold text-muted-foreground">Total Posts</p>
          </div>
          <div className="w-px h-8 bg-border" />
          <div className="text-center">
            <p className="text-2xl font-display font-black text-primary">{posts.filter(p => p.verified).length}</p>
            <p className="text-[10px] font-bold text-muted-foreground">Verified</p>
          </div>
          <div className="w-px h-8 bg-border" />
          <div className="text-center">
            <p className="text-2xl font-display font-black text-emerald-600">{posts.reduce((s, p) => s + p.likes, 0)}</p>
            <p className="text-[10px] font-bold text-muted-foreground">Helpful Votes</p>
          </div>
          <div className="w-px h-8 bg-border" />
          <div className="text-center">
            <p className="text-2xl font-display font-black text-amber-600">{posts.filter(p => p.type === 'warning').length}</p>
            <p className="text-[10px] font-bold text-muted-foreground">Alerts</p>
          </div>
        </div>

        {/* Post Form */}
        {showForm && (
          <div className="bg-card border border-border rounded-2xl p-4 space-y-3">
            <div className="flex items-center justify-between mb-1">
              <h3 className="font-display font-black text-foreground">Share Safety Insight</h3>
              <button onClick={() => setShowForm(false)}><X className="w-4 h-4 text-muted-foreground" /></button>
            </div>

            <input
              className="w-full bg-muted rounded-xl px-4 py-2.5 text-sm outline-none border border-transparent focus:border-primary/30 transition-colors placeholder:text-muted-foreground"
              placeholder="📍 Location (e.g. Marina Beach, Chennai)"
              value={newPost.location}
              onChange={e => setNewPost(p => ({ ...p, location: e.target.value }))}
            />

            <textarea
              className="w-full bg-muted rounded-xl px-4 py-2.5 text-sm outline-none border border-transparent focus:border-primary/30 transition-colors resize-none placeholder:text-muted-foreground"
              rows={3}
              placeholder="Share your safety experience or tip..."
              value={newPost.content}
              onChange={e => setNewPost(p => ({ ...p, content: e.target.value }))}
            />

            <div className="flex gap-2 flex-wrap">
              {(['safe', 'tip', 'warning', 'insight'] as PostType[]).map(t => {
                const cfg = TYPE_CONFIG[t]
                return (
                  <button key={t}
                    onClick={() => setNewPost(p => ({ ...p, type: t }))}
                    className={`text-xs font-bold px-3 py-1.5 rounded-full transition-all ${newPost.type === t ? cfg.badge + ' ring-1 ring-current' : 'bg-muted text-muted-foreground'}`}>
                    {cfg.label}
                  </button>
                )
              })}
            </div>

            <button
              onClick={handlePost}
              className="w-full text-white font-bold py-2.5 rounded-xl text-sm active:scale-[0.99] transition-transform"
              style={{background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'}}>
              Post to Community
            </button>
          </div>
        )}

        {/* Filter Tabs */}
        <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
          {filterTabs.map(tab => (
            <button
              key={tab.key}
              onClick={() => setFilter(tab.key)}
              className={`shrink-0 flex items-center gap-1.5 text-xs font-bold px-3.5 py-2 rounded-full transition-all ${
                filter === tab.key
                  ? 'text-white shadow-md'
                  : 'bg-muted text-muted-foreground hover:text-foreground'
              }`}
              style={filter === tab.key ? {background: 'linear-gradient(135deg, hsl(262 83% 58%), hsl(280 70% 45%))'} : {}}
            >
              <tab.icon className="w-3 h-3" />
              {tab.label}
            </button>
          ))}
        </div>

        {/* Posts Feed */}
        <div className="space-y-3">
          {filtered.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <Users className="w-10 h-10 mx-auto mb-3 opacity-30" />
              <p className="font-semibold">No posts in this category yet</p>
            </div>
          ) : (
            filtered.map(post => (
              <PostCard key={post.id} post={post} onLike={handleLike} />
            ))
          )}
        </div>

      </main>
    </div>
  )
}
