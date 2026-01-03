'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Bot, Check, Cloud, Server, DollarSign, TrendingUp, Sparkles } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useSettingsStore } from '@/lib/stores/app-store';
import { cn } from '@/lib/utils';

interface CostSummary {
  totalCost: number;
  currency: string;
  periodStart: string;
  periodEnd: string;
  costsByService: Array<{ serviceName: string; cost: number }>;
}

interface CostForecast {
  estimatedTotal: number;
  currency: string;
  forecastPeriodEnd: string;
}

interface EnvVarStatus {
  name: string;
  configured: boolean;
  displayValue?: string;
}

interface DetailedProviderStatus {
  activeProvider: 'azure' | 'ollama' | null;
  azure: {
    configured: boolean;
    model: string | null;
    realtimeConfigured: boolean;
    realtimeModel: string | null;
    envVars: EnvVarStatus[];
  };
  ollama: {
    configured: boolean;
    url: string;
    model: string;
    envVars: EnvVarStatus[];
  };
}

export function AIProviderSettings() {
  const { preferredProvider, setPreferredProvider } = useSettingsStore();
  const [providerStatus, setProviderStatus] = useState<DetailedProviderStatus | null>(null);
  const [costs, setCosts] = useState<CostSummary | null>(null);
  const [forecast, setForecast] = useState<CostForecast | null>(null);
  const [loadingCosts, setLoadingCosts] = useState(false);
  const [costsConfigured, setCostsConfigured] = useState(true);
  const [showEnvDetails, setShowEnvDetails] = useState(false);

  // Azure Cost Config form state
  const [azureCostConfig, setAzureCostConfig] = useState({
    tenantId: '',
    clientId: '',
    clientSecret: '',
    subscriptionId: '',
  });
  const [savingCostConfig, setSavingCostConfig] = useState(false);
  const [costConfigSaved, setCostConfigSaved] = useState(false);

  // Load existing config from database
  useEffect(() => {
    const loadConfig = async () => {
      try {
        const res = await fetch('/api/user/settings');
        if (res.ok) {
          const data = await res.json();
          if (data.azureCostConfig) {
            const parsed = JSON.parse(data.azureCostConfig);
            setAzureCostConfig(parsed);
            setCostConfigSaved(true);
          }
        }
      } catch {
        // Failed to load, ignore
      }
    };
    loadConfig();
  }, []);

  // Save cost config to database
  const saveCostConfig = async () => {
    setSavingCostConfig(true);
    try {
      await fetch('/api/user/settings', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ azureCostConfig: JSON.stringify(azureCostConfig) }),
      });
      setCostConfigSaved(true);
      // Note: Server still needs env vars - this is for future API enhancement
      // For now, show success and inform user to also set env vars
    } finally {
      setSavingCostConfig(false);
    }
  };

  // Check provider status on mount
  useEffect(() => {
    fetch('/api/provider/status')
      .then(res => res.json())
      .then(data => setProviderStatus(data))
      .catch(() => setProviderStatus(null));
  }, []);

  // Fetch costs if Azure is the provider
  useEffect(() => {
    if (providerStatus?.activeProvider !== 'azure') return;

    let cancelled = false;

    const fetchCosts = async () => {
      try {
        const [costRes, forecastRes] = await Promise.all([
          fetch('/api/azure/costs?days=30'),
          fetch('/api/azure/costs?type=forecast'),
        ]);

        if (cancelled) return;

        // C-4 FIX: Check response status before parsing
        if (!costRes.ok || !forecastRes.ok) {
          const costData = await costRes.json();
          // If explicitly configured: false, show config form
          if (costData.configured === false) {
            setCostsConfigured(false);
          } else {
            // API error but configured - show error state
            setCostsConfigured(true);
            setCosts(null);
          }
          return;
        }

        const [costData, forecastData] = await Promise.all([
          costRes.json(),
          forecastRes.json(),
        ]);

        // C-4 FIX: Validate response has required fields
        if (costData.error || costData.totalCost === undefined) {
          if (costData.configured === false) {
            setCostsConfigured(false);
          } else {
            setCostsConfigured(true);
            setCosts(null);
          }
          return;
        }

        setCosts(costData);
        setForecast(forecastData.error ? null : forecastData);
      } catch {
        if (!cancelled) setCostsConfigured(false);
      } finally {
        if (!cancelled) setLoadingCosts(false);
      }
    };

    setLoadingCosts(true);
    fetchCosts();

    return () => { cancelled = true; };
  }, [providerStatus?.activeProvider]);

  const formatCurrency = (amount: number, currency = 'USD') => {
    return new Intl.NumberFormat('it-IT', {
      style: 'currency',
      currency,
    }).format(amount);
  };

  return (
    <div className="space-y-6">
      {/* Provider Status */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Bot className="w-5 h-5 text-blue-500" />
            Provider AI Attivo
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {providerStatus === null ? (
            <div className="animate-pulse h-20 bg-slate-100 dark:bg-slate-800 rounded-lg" />
          ) : (
            <>
              {/* Clear Status Banner - Fix for #7 */}
              <div className={cn(
                'p-3 rounded-lg flex items-center gap-3',
                providerStatus.activeProvider === 'azure'
                  ? 'bg-blue-100 dark:bg-blue-900/30 border border-blue-200 dark:border-blue-800'
                  : providerStatus.activeProvider === 'ollama'
                    ? 'bg-green-100 dark:bg-green-900/30 border border-green-200 dark:border-green-800'
                    : 'bg-amber-100 dark:bg-amber-900/30 border border-amber-200 dark:border-amber-800'
              )}>
                <div className={cn(
                  'w-3 h-3 rounded-full animate-pulse',
                  providerStatus.activeProvider === 'azure' ? 'bg-blue-500' :
                  providerStatus.activeProvider === 'ollama' ? 'bg-green-500' : 'bg-amber-500'
                )} />
                <div className="flex-1">
                  <span className="font-medium text-slate-900 dark:text-slate-100">
                    {providerStatus.activeProvider === 'azure' ? 'Azure OpenAI' :
                     providerStatus.activeProvider === 'ollama' ? 'Ollama (Locale)' :
                     'Nessun provider attivo'}
                  </span>
                  <span className="text-sm text-slate-600 dark:text-slate-400 ml-2">
                    {providerStatus.activeProvider === 'azure'
                      ? `Chat + Voice (${providerStatus.azure.model})`
                      : providerStatus.activeProvider === 'ollama'
                        ? `Solo Chat (${providerStatus.ollama.model})`
                        : 'Configura un provider'}
                  </span>
                </div>
                {providerStatus.activeProvider && (
                  <Check className="w-5 h-5 text-green-600 dark:text-green-400" />
                )}
              </div>

              <p className="text-sm text-slate-500 dark:text-slate-400">
                Clicca per selezionare il provider preferito:
              </p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Azure Card - Fix #7: Clear button styling */}
                <button
                  type="button"
                  onClick={() => setPreferredProvider('azure')}
                  className={cn(
                    'p-4 rounded-xl border-2 transition-all text-left',
                    'focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-slate-900 focus:ring-blue-500',
                    'hover:shadow-md active:scale-[0.99]',
                    preferredProvider === 'azure' && 'ring-2 ring-accent-themed ring-offset-2 dark:ring-offset-slate-900',
                    providerStatus.activeProvider === 'azure'
                      ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20 shadow-md'
                      : providerStatus.azure.configured
                        ? 'border-slate-300 dark:border-slate-600 hover:border-blue-400 hover:bg-blue-50/50 dark:hover:bg-blue-900/10'
                        : 'border-slate-200 dark:border-slate-700 opacity-60 cursor-not-allowed'
                  )}
                  disabled={!providerStatus.azure.configured}
                >
                  <div className="flex items-center gap-3 mb-2">
                    <Cloud className="w-6 h-6 text-blue-500" />
                    <div className="flex-1">
                      <h4 className="font-medium">Azure OpenAI</h4>
                      <p className="text-xs text-slate-500">Cloud - Chat + Voice</p>
                    </div>
                    {providerStatus.azure.configured ? (
                      <span className="px-2 py-0.5 text-xs rounded-full bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-400">
                        Configurato
                      </span>
                    ) : (
                      <span className="px-2 py-0.5 text-xs rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500">
                        Non configurato
                      </span>
                    )}
                  </div>
                  {providerStatus.activeProvider === 'azure' && (
                    <div className="mt-2 flex items-center gap-2">
                      <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                      <span className="text-sm text-green-600 dark:text-green-400">
                        Attivo: {providerStatus.azure.model}
                      </span>
                    </div>
                  )}
                  {providerStatus.azure.realtimeConfigured && (
                    <div className="mt-1 text-xs text-blue-600 dark:text-blue-400">
                      Voice: {providerStatus.azure.realtimeModel}
                    </div>
                  )}
                </button>

                {/* Ollama Card - Fix #7: Clear button styling */}
                <button
                  type="button"
                  onClick={() => setPreferredProvider('ollama')}
                  className={cn(
                    'p-4 rounded-xl border-2 transition-all text-left',
                    'focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-slate-900 focus:ring-green-500',
                    'hover:shadow-md active:scale-[0.99]',
                    preferredProvider === 'ollama' && 'ring-2 ring-accent-themed ring-offset-2 dark:ring-offset-slate-900',
                    providerStatus.activeProvider === 'ollama'
                      ? 'border-green-500 bg-green-50 dark:bg-green-900/20 shadow-md'
                      : providerStatus.ollama.configured
                        ? 'border-slate-300 dark:border-slate-600 hover:border-green-400 hover:bg-green-50/50 dark:hover:bg-green-900/10'
                        : 'border-slate-200 dark:border-slate-700 opacity-60 cursor-not-allowed'
                  )}
                  disabled={!providerStatus.ollama.configured}
                >
                  <div className="flex items-center gap-3 mb-2">
                    <Server className="w-6 h-6 text-green-500" />
                    <div className="flex-1">
                      <h4 className="font-medium">Ollama</h4>
                      <p className="text-xs text-slate-500">Locale - Solo Chat</p>
                    </div>
                    {providerStatus.ollama.configured ? (
                      <span className="px-2 py-0.5 text-xs rounded-full bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-400">
                        In esecuzione
                      </span>
                    ) : (
                      <span className="px-2 py-0.5 text-xs rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500">
                        Non attivo
                      </span>
                    )}
                  </div>
                  {providerStatus.activeProvider === 'ollama' && (
                    <div className="mt-2 flex items-center gap-2">
                      <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                      <span className="text-sm text-green-600 dark:text-green-400">
                        Attivo: {providerStatus.ollama.model}
                      </span>
                    </div>
                  )}
                  <div className="mt-1 text-xs text-slate-500">
                    URL: {providerStatus.ollama.url}
                  </div>
                </button>
              </div>

              {/* Selection Mode Indicator */}
              <div className="flex items-center justify-between p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg">
                <div className="flex items-center gap-2">
                  <span className="text-sm text-slate-600 dark:text-slate-400">
                    Modalità selezione:
                  </span>
                  <span className={cn(
                    'px-2 py-0.5 text-xs font-medium rounded-full',
                    preferredProvider === 'auto'
                      ? 'bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-300'
                      : preferredProvider === 'azure'
                        ? 'bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300'
                        : 'bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-300'
                  )}>
                    {preferredProvider === 'auto' ? 'Automatica' : preferredProvider === 'azure' ? 'Azure' : 'Ollama'}
                  </span>
                </div>
                {preferredProvider !== 'auto' && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setPreferredProvider('auto')}
                    className="text-xs"
                  >
                    Ripristina Auto
                  </Button>
                )}
              </div>

              {/* No provider warning */}
              {!providerStatus.activeProvider && (
                <div className="p-4 bg-amber-50 dark:bg-amber-900/20 rounded-xl border border-amber-200 dark:border-amber-800">
                  <h4 className="font-medium text-amber-700 dark:text-amber-300">
                    Nessun provider configurato
                  </h4>
                  <p className="text-sm text-amber-600 dark:text-amber-400 mt-1">
                    Configura Azure OpenAI nel file .env oppure avvia Ollama localmente.
                  </p>
                </div>
              )}

              {/* Environment Variables Toggle */}
              <button
                onClick={() => setShowEnvDetails(!showEnvDetails)}
                className="flex items-center gap-2 text-sm text-slate-500 hover:text-slate-700 dark:hover:text-slate-300 transition-colors"
              >
                <span>{showEnvDetails ? '▼' : '▶'}</span>
                <span>Mostra configurazione .env</span>
              </button>

              {/* Environment Variables Details */}
              {showEnvDetails && (
                <div className="space-y-4 pt-2">
                  {/* Azure env vars */}
                  <div className="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl">
                    <h5 className="font-medium text-sm mb-3 flex items-center gap-2">
                      <Cloud className="w-4 h-4 text-blue-500" />
                      Azure OpenAI (Chat + Voice)
                    </h5>
                    <div className="space-y-2">
                      {providerStatus.azure.envVars.map((envVar) => (
                        <div key={envVar.name} className="flex items-center justify-between text-xs">
                          <code className="font-mono text-slate-600 dark:text-slate-400">
                            {envVar.name}
                          </code>
                          <div className="flex items-center gap-2">
                            {envVar.configured ? (
                              <>
                                <span className="text-green-600 dark:text-green-400">
                                  {envVar.displayValue || '****'}
                                </span>
                                <span className="w-2 h-2 rounded-full bg-green-500" />
                              </>
                            ) : (
                              <>
                                <span className="text-slate-400">Non configurato</span>
                                <span className="w-2 h-2 rounded-full bg-slate-300 dark:bg-slate-600" />
                              </>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Ollama env vars */}
                  <div className="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl">
                    <h5 className="font-medium text-sm mb-3 flex items-center gap-2">
                      <Server className="w-4 h-4 text-green-500" />
                      Ollama (Solo Chat locale)
                    </h5>
                    <div className="space-y-2">
                      {providerStatus.ollama.envVars.map((envVar) => (
                        <div key={envVar.name} className="flex items-center justify-between text-xs">
                          <code className="font-mono text-slate-600 dark:text-slate-400">
                            {envVar.name}
                          </code>
                          <div className="flex items-center gap-2">
                            <span className={envVar.configured ? 'text-green-600 dark:text-green-400' : 'text-slate-400'}>
                              {envVar.displayValue || 'Default'}
                            </span>
                            <span className={cn(
                              'w-2 h-2 rounded-full',
                              envVar.configured ? 'bg-green-500' : 'bg-slate-300 dark:bg-slate-600'
                            )} />
                          </div>
                        </div>
                      ))}
                    </div>
                    <div className="mt-3 p-2 bg-slate-100 dark:bg-slate-700 rounded text-xs">
                      <p className="text-slate-600 dark:text-slate-400">
                        Per usare Ollama, avvialo con:
                      </p>
                      <code className="block mt-1 text-green-600 dark:text-green-400 font-mono">
                        ollama serve && ollama pull llama3.2
                      </code>
                    </div>
                  </div>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>

      {/* Azure Costs - Only show if Azure is active */}
      {providerStatus?.activeProvider === 'azure' && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <DollarSign className="w-5 h-5 text-green-500" />
              Costi Azure OpenAI
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {!costsConfigured ? (
              <div className="p-4 bg-amber-50 dark:bg-amber-900/20 rounded-xl border border-amber-200 dark:border-amber-800">
                <h4 className="font-medium text-amber-700 dark:text-amber-300 mb-2">
                  Cost Management non configurato
                </h4>
                <p className="text-sm text-amber-600 dark:text-amber-400 mb-3">
                  Per visualizzare i costi Azure, configura un Service Principal con ruolo &quot;Cost Management Reader&quot;:
                </p>

                {/* Cost Config Form */}
                <div className="space-y-3 mb-4">
                  <input
                    type="text"
                    placeholder="AZURE_TENANT_ID"
                    value={azureCostConfig.tenantId}
                    onChange={(e) => setAzureCostConfig(prev => ({...prev, tenantId: e.target.value}))}
                    className="w-full px-3 py-2 text-sm rounded-lg bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <input
                    type="text"
                    placeholder="AZURE_CLIENT_ID"
                    value={azureCostConfig.clientId}
                    onChange={(e) => setAzureCostConfig(prev => ({...prev, clientId: e.target.value}))}
                    className="w-full px-3 py-2 text-sm rounded-lg bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <input
                    type="password"
                    placeholder="AZURE_CLIENT_SECRET"
                    value={azureCostConfig.clientSecret}
                    onChange={(e) => setAzureCostConfig(prev => ({...prev, clientSecret: e.target.value}))}
                    className="w-full px-3 py-2 text-sm rounded-lg bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <input
                    type="text"
                    placeholder="AZURE_SUBSCRIPTION_ID"
                    value={azureCostConfig.subscriptionId}
                    onChange={(e) => setAzureCostConfig(prev => ({...prev, subscriptionId: e.target.value}))}
                    className="w-full px-3 py-2 text-sm rounded-lg bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <Button
                    onClick={saveCostConfig}
                    disabled={savingCostConfig || !azureCostConfig.tenantId || !azureCostConfig.clientId || !azureCostConfig.clientSecret || !azureCostConfig.subscriptionId}
                    className="w-full"
                  >
                    {savingCostConfig ? 'Salvataggio...' : costConfigSaved ? 'Configurazione Salvata' : 'Salva Configurazione'}
                  </Button>
                </div>

                {costConfigSaved && (
                  <div className="p-3 bg-green-50 dark:bg-green-900/20 rounded-lg border border-green-200 dark:border-green-800 mb-3">
                    <p className="text-sm text-green-700 dark:text-green-400">
                      Configurazione salvata localmente. Per attivare i costi, aggiungi anche le variabili nel file .env del server.
                    </p>
                  </div>
                )}

                <div className="bg-slate-900 dark:bg-slate-950 p-3 rounded-lg">
                  <p className="text-xs text-slate-400 mb-2">Variabili .env richieste:</p>
                  <code className="text-xs text-green-400 font-mono block leading-relaxed">
                    AZURE_TENANT_ID=...<br />
                    AZURE_CLIENT_ID=...<br />
                    AZURE_CLIENT_SECRET=...<br />
                    AZURE_SUBSCRIPTION_ID=...
                  </code>
                </div>
              </div>
            ) : loadingCosts ? (
              <div className="animate-pulse space-y-4">
                <div className="h-24 bg-slate-100 dark:bg-slate-800 rounded-lg" />
              </div>
            ) : costs ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="p-4 bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/30 dark:to-blue-800/30 rounded-xl">
                  <div className="flex items-center gap-2 mb-2">
                    <DollarSign className="w-5 h-5 text-blue-600" />
                    <span className="text-sm text-blue-600 dark:text-blue-400">Ultimi 30 giorni</span>
                  </div>
                  <p className="text-2xl font-bold text-blue-700 dark:text-blue-300">
                    {formatCurrency(costs.totalCost, costs.currency)}
                  </p>
                </div>
                {forecast && (
                  <div className="p-4 bg-gradient-to-br from-green-50 to-green-100 dark:from-green-900/30 dark:to-green-800/30 rounded-xl">
                    <div className="flex items-center gap-2 mb-2">
                      <TrendingUp className="w-5 h-5 text-green-600" />
                      <span className="text-sm text-green-600 dark:text-green-400">Stima fine mese</span>
                    </div>
                    <p className="text-2xl font-bold text-green-700 dark:text-green-300">
                      {formatCurrency(forecast.estimatedTotal, forecast.currency)}
                    </p>
                  </div>
                )}
              </div>
            ) : (
              // C-4 FIX: Show error message when costs data unavailable
              <div className="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700">
                <p className="text-sm text-slate-600 dark:text-slate-400">
                  Impossibile recuperare i dati sui costi Azure. Verifica la connessione o riprova piu tardi.
                </p>
              </div>
            )}
          </CardContent>
        </Card>
      )}

      {/* Voice availability info */}
      <Card>
        <CardHeader>
          <CardTitle>Funzionalita Voce</CardTitle>
        </CardHeader>
        <CardContent>
          {providerStatus?.azure.realtimeConfigured ? (
            <div className="p-4 bg-green-50 dark:bg-green-900/20 rounded-xl">
              <div className="flex items-center gap-2 mb-2">
                <span className="w-3 h-3 rounded-full bg-green-500" />
                <span className="font-medium text-green-700 dark:text-green-300">
                  Voce disponibile
                </span>
              </div>
              <p className="text-sm text-green-600 dark:text-green-400">
                Azure OpenAI Realtime: {providerStatus.azure.realtimeModel}
              </p>
            </div>
          ) : (
            <div className="p-4 bg-amber-50 dark:bg-amber-900/20 rounded-xl">
              <div className="flex items-center gap-2 mb-2">
                <span className="w-3 h-3 rounded-full bg-amber-500" />
                <span className="font-medium text-amber-700 dark:text-amber-300">
                  Voce non disponibile
                </span>
              </div>
              <p className="text-sm text-amber-600 dark:text-amber-400 mb-2">
                Le conversazioni vocali richiedono Azure OpenAI Realtime.
              </p>
              <p className="text-xs text-slate-500">
                Configura: AZURE_OPENAI_REALTIME_ENDPOINT, AZURE_OPENAI_REALTIME_API_KEY, AZURE_OPENAI_REALTIME_DEPLOYMENT
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Showcase Mode */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Sparkles className="w-5 h-5 text-purple-500" />
            Modalità Showcase
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-slate-600 dark:text-slate-400 mb-4">
            Esplora MirrorBuddy senza configurare un provider AI. Demo interattive
            con contenuti statici: maestri, quiz, flashcards, mappe mentali e altro.
          </p>
          <Link href="/showcase">
            <Button variant="outline" className="w-full gap-2">
              <Sparkles className="w-4 h-4" />
              Apri Showcase
            </Button>
          </Link>
        </CardContent>
      </Card>
    </div>
  );
}

