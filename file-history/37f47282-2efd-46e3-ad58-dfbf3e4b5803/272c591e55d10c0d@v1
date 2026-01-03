'use client';

import { useState, useEffect } from 'react';
import { useTheme } from 'next-themes';
import { Sun, Moon, Laptop, Globe, Check } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { cn } from '@/lib/utils';

// Appearance Settings
interface AppearanceSettingsProps {
  appearance: {
    theme: 'light' | 'dark' | 'system';
    accentColor: string;
    language: 'it' | 'en' | 'es' | 'fr' | 'de';
  };
  onUpdate: (updates: Partial<AppearanceSettingsProps['appearance']>) => void;
}

export function AppearanceSettings({ appearance, onUpdate }: AppearanceSettingsProps) {
  const { theme: currentTheme, setTheme, resolvedTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  // Avoid hydration mismatch - standard Next.js pattern for client-only rendering
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- Hydration pattern: safe one-time mount state
    setMounted(true);
  }, []);

  const themes: Array<{ value: 'light' | 'dark' | 'system'; label: string; icon: React.ReactNode }> = [
    { value: 'light', label: 'Chiaro', icon: <Sun className="w-5 h-5" /> },
    { value: 'dark', label: 'Scuro', icon: <Moon className="w-5 h-5" /> },
    { value: 'system', label: 'Sistema', icon: <Laptop className="w-5 h-5" /> },
  ];

  const accentColors = [
    { value: 'blue', label: 'Blu', class: 'bg-blue-500' },
    { value: 'green', label: 'Verde', class: 'bg-green-500' },
    { value: 'purple', label: 'Viola', class: 'bg-purple-500' },
    { value: 'orange', label: 'Arancione', class: 'bg-orange-500' },
    { value: 'pink', label: 'Rosa', class: 'bg-pink-500' },
  ];

  const handleThemeChange = (newTheme: 'light' | 'dark' | 'system') => {
    setTheme(newTheme);
    onUpdate({ theme: newTheme });
  };

  // Show loading state during hydration
  if (!mounted) {
    return (
      <div className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle>Tema</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-3 gap-4">
              {themes.map(theme => (
                <div
                  key={theme.value}
                  className="flex flex-col items-center gap-2 p-4 rounded-xl border-2 border-slate-200 dark:border-slate-700"
                >
                  {theme.icon}
                  <span className="text-sm font-medium">{theme.label}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Tema</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-3 gap-4">
            {themes.map(theme => (
              <button
                key={theme.value}
                onClick={() => handleThemeChange(theme.value)}
                className={cn(
                  'flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all',
                  currentTheme === theme.value
                    ? 'border-accent-themed bg-primary/10'
                    : 'border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600'
                )}
              >
                {theme.icon}
                <span className="text-sm font-medium">{theme.label}</span>
              </button>
            ))}
          </div>
          {currentTheme === 'system' && (
            <p className="text-sm text-slate-500 mt-3">
              Tema corrente: {resolvedTheme === 'dark' ? 'Scuro' : 'Chiaro'} (basato sulle preferenze di sistema)
            </p>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Colore Principale</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex gap-3">
            {accentColors.map(color => (
              <button
                key={color.value}
                onClick={() => onUpdate({ accentColor: color.value })}
                className={cn(
                  'w-12 h-12 rounded-full transition-transform',
                  color.class,
                  appearance.accentColor === color.value
                    ? 'ring-4 ring-offset-2 ring-offset-background ring-slate-400 dark:ring-slate-500 scale-110'
                    : 'hover:scale-105'
                )}
                title={color.label}
              />
            ))}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Globe className="w-5 h-5 text-blue-500" />
            Lingua
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-slate-500 mb-4">
            Seleziona la lingua in cui i professori ti parleranno
          </p>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
            {[
              { value: 'it' as const, label: 'Italiano', flag: '🇮🇹' },
              { value: 'en' as const, label: 'English', flag: '🇬🇧' },
              { value: 'es' as const, label: 'Español', flag: '🇪🇸' },
              { value: 'fr' as const, label: 'Français', flag: '🇫🇷' },
              { value: 'de' as const, label: 'Deutsch', flag: '🇩🇪' },
            ].map(lang => {
              const isSelected = (appearance.language || 'it') === lang.value;
              return (
                <button
                  key={lang.value}
                  onClick={() => onUpdate({ language: lang.value })}
                  className={cn(
                    'flex items-center gap-2 p-3 rounded-xl border-2 transition-all font-medium',
                    'focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-slate-900',
                    isSelected
                      ? 'bg-accent-themed text-white border-accent-themed shadow-lg focus:ring-accent-themed'
                      : 'bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-600 hover:border-accent-themed hover:bg-slate-50 dark:hover:bg-slate-700 shadow-sm hover:shadow-md focus:ring-accent-themed'
                  )}
                  aria-pressed={isSelected}
                >
                  <span className="text-xl">{lang.flag}</span>
                  <span className="text-sm">{lang.label}</span>
                  {isSelected && (
                    <Check className="w-4 h-4 ml-auto" />
                  )}
                </button>
              );
            })}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
