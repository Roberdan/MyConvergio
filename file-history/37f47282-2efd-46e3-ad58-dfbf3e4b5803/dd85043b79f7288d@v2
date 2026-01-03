'use client';

import { useRouter } from 'next/navigation';
import { User, RotateCcw } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import type { TeachingStyle } from '@/lib/stores/app-store';
import { TEACHING_STYLES } from '../constants';

// Profile Settings
interface ProfileSettingsProps {
  profile: {
    name: string;
    gradeLevel: string;
    learningGoals: string[];
    teachingStyle: TeachingStyle;
  };
  onUpdate: (updates: Partial<ProfileSettingsProps['profile']>) => void;
}

export function ProfileSettings({ profile, onUpdate }: ProfileSettingsProps) {
  const router = useRouter();

  const gradeLevels = [
    { value: '', label: 'Seleziona...' },
    { value: 'primary', label: 'Scuola Primaria (6-10 anni)' },
    { value: 'middle', label: 'Scuola Media (11-13 anni)' },
    { value: 'high', label: 'Scuola Superiore (14-18 anni)' },
    { value: 'university', label: 'Universita' },
    { value: 'adult', label: 'Formazione Continua' },
  ];

  const currentStyle = TEACHING_STYLES.find(s => s.value === (profile.teachingStyle || 'balanced'));

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <User className="w-5 h-5 text-blue-500" />
              Informazioni Personali
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                Nome
              </label>
              <input
                type="text"
                value={profile.name || ''}
                onChange={(e) => onUpdate({ name: e.target.value })}
                placeholder="Come ti chiami?"
                className="w-full px-4 py-2.5 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                Livello di istruzione
              </label>
              <select
                value={profile.gradeLevel || ''}
                onChange={(e) => onUpdate({ gradeLevel: e.target.value })}
                className="w-full px-4 py-2.5 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                {gradeLevels.map(level => (
                  <option key={level.value} value={level.value}>
                    {level.label}
                  </option>
                ))}
              </select>
            </div>
          </CardContent>
        </Card>

      </div>

      {/* Teaching Style Card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <span className="text-2xl">{currentStyle?.emoji || '⚖️'}</span>
            Stile dei Professori
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-slate-500">
            Scegli come vuoi che i professori ti parlino e ti correggano
          </p>

          {/* Current style display */}
          <div className={cn(
            'p-4 rounded-xl bg-gradient-to-r text-white',
            currentStyle?.color || 'from-blue-400 to-indigo-500'
          )}>
            <div className="flex items-center gap-3">
              <span className="text-3xl">{currentStyle?.emoji}</span>
              <div>
                <h4 className="font-bold text-lg">{currentStyle?.label}</h4>
                <p className="text-sm opacity-90">{currentStyle?.description}</p>
              </div>
            </div>
          </div>

          {/* Style selector */}
          <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
            {TEACHING_STYLES.map(style => (
              <button
                key={style.value}
                onClick={() => onUpdate({ teachingStyle: style.value })}
                className={cn(
                  'p-3 rounded-xl border-2 transition-all text-center',
                  (profile.teachingStyle || 'balanced') === style.value
                    ? 'border-slate-900 dark:border-white bg-slate-100 dark:bg-slate-800 scale-105'
                    : 'border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600'
                )}
              >
                <span className="text-2xl block mb-1">{style.emoji}</span>
                <span className="text-xs font-medium">{style.label}</span>
              </button>
            ))}
          </div>

          {/* Style impact preview */}
          <div className="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl">
            <h5 className="text-sm font-medium mb-2">Esempio di feedback:</h5>
            <p className="text-sm text-slate-600 dark:text-slate-400 italic">
              {profile.teachingStyle === 'super_encouraging' && (
                '"Fantastico! Stai andando benissimo! Ogni errore e un passo verso il successo!"'
              )}
              {profile.teachingStyle === 'encouraging' && (
                '"Ottimo lavoro! Hai quasi ragione, prova a pensare un attimo..."'
              )}
              {(profile.teachingStyle === 'balanced' || !profile.teachingStyle) && (
                '"Buon tentativo. C\'e un errore qui - ripassa il concetto e riprova."'
              )}
              {profile.teachingStyle === 'strict' && (
                '"Sbagliato. Hai saltato un passaggio fondamentale. Torna indietro e rifai."'
              )}
              {profile.teachingStyle === 'brutal' && (
                '"No. Completamente sbagliato. Devi studiare di piu, non ci siamo proprio."'
              )}
            </p>
          </div>
        </CardContent>
      </Card>

      {/* Wave 3: Review Introduction Card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <RotateCcw className="w-5 h-5 text-pink-500" />
            Introduzione
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-slate-500 dark:text-slate-400">
            Rivedi l&apos;introduzione a MirrorBuddy e scopri tutte le funzionalita disponibili.
          </p>
          <Button
            variant="outline"
            onClick={() => router.push('/welcome?replay=true')}
            className="w-full sm:w-auto"
          >
            <RotateCcw className="w-4 h-4 mr-2" />
            Rivedi introduzione
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
