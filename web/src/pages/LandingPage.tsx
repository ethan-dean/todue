import React, { useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { CalendarCheck, Bookmark, ListChecks, RefreshCw, Smartphone, ArrowRightCircle, Repeat, BarChart2, Github } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';

const features = [
  {
    icon: CalendarCheck,
    title: 'Day-to-Day Todos',
    description: 'Organize your tasks by date and stay on top of what matters today.',
  },
  {
    icon: Bookmark,
    title: 'Later Lists',
    description: 'Save ideas and tasks for later in organized, custom lists.',
  },
  {
    icon: ListChecks,
    title: 'Step-by-Step Routines',
    description: 'Build repeatable routines and follow them with guided execution.',
  },
  {
    icon: RefreshCw,
    title: 'Real-time Sync',
    description: 'Changes sync instantly across all your devices.',
  },
  {
    icon: Smartphone,
    title: 'Web, iOS & Android',
    description: 'Use Todue anywhere — your tasks are always with you.',
  },
  {
    icon: ArrowRightCircle,
    title: 'Auto Rollover',
    description: "Unfinished todos automatically move to today so nothing slips through.",
  },
  {
    icon: Repeat,
    title: 'Recurring Tasks',
    description: 'Set tasks to repeat daily, weekly, monthly, or on your own schedule.',
  },
  {
    icon: BarChart2,
    title: 'Routine Insights',
    description: 'Track streaks, completion times, and build better habits over time.',
  },
];

const webTabs = [
  { label: 'Now', key: 'now' },
  { label: 'Later', key: 'later' },
  { label: 'Routines', key: 'routines' },
];

const LandingPage: React.FC = () => {
  const { isAuthenticated, isLoading } = useAuth();
  const { theme } = useTheme();
  const suffix = theme === 'dark' ? 'dark' : 'light';
  const [activeTab, setActiveTab] = useState('now');

  if (isLoading) {
    return (
      <div className="loading-container">
        <div className="loading-spinner">Loading...</div>
      </div>
    );
  }

  if (isAuthenticated) {
    return <Navigate to="/app" replace />;
  }

  const activeTabData = webTabs.find(t => t.key === activeTab)!;

  return (
    <div className="landing-page">

      {/* Hero */}
      <div className="landing-hero">
        <div className="landing-hero-glow" />
        <img src="/icon.png" alt="Todue" className={`landing-icon${theme === 'dark' ? ' landing-icon--dark' : ''}`} />
        <h1 className="landing-title">Todue</h1>
        <p className="landing-subtitle">
          The open-source, self-hosted todo app.
        </p>
        <p className="landing-tagline">
          Own your data. Host it yourself. A simple, powerful task manager
          built for people who care about privacy and control.
        </p>
        <div className="landing-cta">
          <Link to="/register" className="landing-btn landing-btn-primary">
            Get Started
          </Link>
          <Link to="/login" className="landing-btn landing-btn-secondary">
            Sign In
          </Link>
        </div>
        <a
          href="https://github.com/ethan-dean/todue"
          target="_blank"
          rel="noopener noreferrer"
          className="landing-github-link"
        >
          <Github size={16} />
          View on GitHub
        </a>
      </div>

      {/* Web Screenshots */}
      <div className="landing-web-section">
        <p className="landing-eyebrow">Powerful on the Web</p>
        <h2 className="landing-section-heading">Everything you need</h2>
        <div className="landing-web-tabs">
          {webTabs.map(tab => (
            <button
              key={tab.key}
              className={`landing-web-tab${activeTab === tab.key ? ' landing-web-tab--active' : ''}`}
              onClick={() => setActiveTab(tab.key)}
            >
              {tab.label}
            </button>
          ))}
        </div>
        <div className="landing-web-featured">
          <img
            key={`${activeTabData.key}-${suffix}`}
            src={`/screenshots/web-${activeTabData.key}-${suffix}.png`}
            alt={`Todue — ${activeTabData.label}`}
            className="landing-web-featured-img"
          />
        </div>
      </div>

      {/* Mobile Screenshots */}
      <div className="landing-mobile-section">
        <p className="landing-eyebrow">Native on Mobile</p>
        <h2 className="landing-section-heading">iOS & Android</h2>
        <div className="landing-mobile-strip">
          {[
            { file: `mobile-now-${suffix}`, alt: 'Now view' },
            { file: `mobile-later-${suffix}`, alt: 'Later Lists' },
            { file: `mobile-laterdetail-${suffix}`, alt: 'Later List detail' },
            { file: `mobile-routine-${suffix}`, alt: 'Routines' },
            { file: `mobile-routinedetail-${suffix}`, alt: 'Routine detail' },
            { file: `mobile-routineanalytics-${suffix}`, alt: 'Routine analytics' },
          ].map((img, i) => (
            <div
              key={img.file}
              className={`landing-phone-item${i % 2 === 1 ? ' landing-phone-item--offset' : ''}`}
            >
              <img
                src={`/screenshots/${img.file}.png`}
                alt={`Todue — ${img.alt} on mobile`}
                className="landing-phone-img"
              />
            </div>
          ))}
        </div>
      </div>

      {/* Features */}
      <div className="landing-features-section">
        <p className="landing-eyebrow">Feature-packed</p>
        <h2 className="landing-section-heading">Built for real use</h2>
        <div className="landing-features">
          {features.map((feature) => (
            <div key={feature.title} className="landing-feature-card">
              <div className="landing-feature-icon-wrap">
                <feature.icon size={22} />
              </div>
              <h3 className="landing-feature-title">{feature.title}</h3>
              <p className="landing-feature-desc">{feature.description}</p>
            </div>
          ))}
        </div>
      </div>

    </div>
  );
};

export default LandingPage;
