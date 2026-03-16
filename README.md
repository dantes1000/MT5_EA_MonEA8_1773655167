```markdown
# MonEA8 - Expert Advisor pour MetaTrader 5

## Description
MonEA8 est un Expert Advisor (EA) avancé pour MetaTrader 5, implémentant une stratégie de **Breakout de Range sur la Session Asiatique**. L'EA identifie des ranges de consolidation formés pendant la session asiatique (00:00 - 06:00 GMT) et cherche à trader la cassure de ces niveaux lors de l'ouverture des marchés européens.

La stratégie intègre de multiples couches de filtres (tendance, volume, volatilité, actualités) et une gestion des risques stricte, la rendant adaptée à un trading discipliné et prop firm-friendly.

## Stratégie Principale
*   **Type de Signal** : Cassure (Breakout) d'un range de prix.
*   **Direction** : Long et/ou Short (configurable).
*   **Période du Range** : Session asiatique (6 heures).
*   **Timeframe d'Analyse (Range)** : Quotidien (D1).
*   **Timeframe d'Exécution** : M15 ou M30 (paramétrable).
*   **Entrée** : Ordres en attente (Buy Stop / Sell Stop) placés après 08:00 GMT.
*   **Confirmation** : Volume élevé (>1.5x la moyenne) et mouvement >1.25x l'ATR.
*   **Filtre de Tendance Principal** : EMA200 sur H1. Achat uniquement si prix > EMA, vente si prix < EMA.

## Prérequis
*   **Plateforme** : MetaTrader 5 (Build 2000+ recommandé).
*   **Compte** : Compte de trading Forex (Hedging recommandé).
*   **Broker** : Fournissant des données de volume réel (ticks) et un spread compétitif.
*   **Symboles** : Paires majeures recommandées (ex: EURUSD, GBPUSD).
*   **Indicateur** : L'EA utilise l'indicateur `FFCal` intégré à MT5 pour le filtre d'actualités. Assurez-vous qu'il est chargé.

## Installation
1.  Téléchargez les fichiers de l'EA (`MonEA8.mq5` et les fichiers `.mqh` inclus).
2.  Ouvrez le dossier de données de MetaTrader 5 (`Fichier > Ouvrir le Dossier de Données`).
3.  Naviguez vers `MQL5/Experts/`.
4.  Copiez le fichier `MonEA8.mq5` dans ce dossier.
5.  Copiez tous les fichiers `.mqh` (s'ils existent) dans le dossier `MQL5/Includes/`.
6.  Redémarrez MetaTrader 5 ou actualisez la fenêtre de l'Observateur de Marché (clic droit > Rafraîchir).
7.  L'EA `MonEA8` apparaîtra maintenant dans l'onglet "Experts" du Navigateur. Glissez-le sur un graphique.

## Paramètres Configurables

### 1. Paramètres du Breakout
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `BreakoutType` | 0 | Type de breakout: 0=Range, 1=BollingerBands, 2=ATR. |
| `AllowLong` | true | Autoriser les positions d'achat (Long). |
| `AllowShort` | true | Autoriser les positions de vente (Short). |
| `RequireVolumeConfirm` | true | Exiger une confirmation par le volume pour valider un breakout. |
| `RangeTF` | `PERIOD_D1` | Timeframe pour le calcul du range (D1). |
| `TrendFilterEMA` | 200 | Période de l'EMA utilisée comme filtre de tendance globale. Mettre à 0 pour désactiver. |
| `ExecTF` | `PERIOD_M15` | Timeframe pour l'exécution des ordres et la surveillance (M15 ou M30). |

### 2. Filtre d'Actualités Économiques (News)
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `UseNewsFilter` | true | Activer/désactiver le filtre d'actualités. |
| `NewsMinutesBefore` | 60 | Minutes avant une annonce à fort impact pour suspendre le trading. |
| `NewsMinutesAfter` | 30 | Minutes après une annonce pour reprendre le trading. |
| `NewsImpactLevel` | 3 | Niveau d'impact minimum à filtrer : 1=Faible, 2=Moyen, 3=Fort. |
| `CloseOnHighImpact` | true | Fermer automatiquement les positions ouvertes avant une annonce à fort impact. |

### 3. Filtres Indicateurs
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `UseATRFilter` | true | Activer le filtre de volatilité ATR. |
| `ATRPeriod` | 14 | Période de calcul de l'ATR. |
| `MinATRPips` / `MaxATRPips` | 20 / 150 | Plage de volatilité ATR (en pips) autorisée pour trader. |
| `ATR_Mult_Min` | 1.25 | Le mouvement de cassure doit être > ATR * ce multiplicateur. |
| `UseBBFilter` | true | Activer le filtre de largeur de range (Bollinger Bands). |
| `Min_Width_Pips` / `Max_Width_Pips` | 30 / 120 | Largeur minimale et maximale autorisée pour le range (pips). |
| `UseEMAFilter` | true | Activer le filtre de tendance EMA. |
| `EMAPeriod` / `EMATf` | 200 / `PERIOD_H1` | Période et timeframe de l'EMA de tendance. |
| `UseADXFilter` | true | Activer le filtre de force de tendance ADX. |
| `ADXThreshold` | 20.0 | Valeur ADX minimum pour considérer une tendance. |
| `UseVolumeFilter` | true | Activer le filtre de confirmation par le volume. |
| `VolumeMultiplier` | 1.5 | Le volume actuel doit être > Moyenne(Volume,20) * ce multiplicateur. |

### 4. Gestion des Positions et des Risques
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `MagicNumber` | 123456 | Identifiant unique pour les ordres de cet EA. |
| `LotMethod` | 0 | Méthode de calcul du lot : 0=% du capital, 1=Fixe, 2=Par pip. |
| `RiskPercent` | 1.0 | Pourcentage du capital (Equity) à risquer par trade (si LotMethod=0). |
| `FixedLot` | 0.01 | Taille de lot fixe (si LotMethod=1). |
| `StopLossPips` | 0 | Stop Loss fixe en pips. 0 = Stop Loss placé à l'opposé du range. |
| `RiskRewardRatio` | 1.5 | Ratio Risque/Rendement cible minimum. |
| `MaxDailyDDPercent` | 5.0 | Drawdown quotidien maximum autorisé (en %). Le trading s'arrête si atteint. |
| `MaxOpenTrades` | 1 | Nombre maximum de positions ouvertes simultanément. |
| `MaxTradesPerDay` | 3 | Nombre maximum de trades à prendre dans une journée. |
| `UseTrailingStop` | true | Activer le trailing stop dynamique. |
| `Trail_Method` | 1 | Méthode de trailing : 0=Fixe (pips), 1=Basé sur ATR. |
| `Trail_Mult` | 0.5 | Multiplicateur ATR pour la distance du trailing stop. |
| `Trail_Activation_PC` | 50 | Pourcentage du profit cible atteint avant d'activer le trailing. |

### 5. Filtres Temporels
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `TradeStartHour` | 8 | Heure GMT de début de la fenêtre de trading (ouverture Londres). |
| `TradeEndHour` | 23 | Heure GMT de fin de la fenêtre de trading. |
| `TradeMonday` ... `TradeFriday` | true | Jours de la semaine où le trading est autorisé. |
| `WeekendClose` | true | Fermer toutes les positions avant le week-end. |
| `FridayCloseHour` | 21 | Heure GMT de fermeture forcée le vendredi. |

## Utilisation
1.  **Graphique** : Attachez l'EA `MonEA8` sur un graphique H1 ou D1 de la paire de devises souhaitée (ex: EURUSD). Le timeframe d'exécution (`ExecTF`) est géré en interne.
2.  **Activation** : Assurez-vous que le bouton "Auto Trading" (ou "Algo Trading") est activé dans MT5.
3.  **Paramétrage Initial** : Il est fortement recommandé de tester l'EA d'abord en mode **Backtest** et sur un **compte de démonstration** pour valider les paramètres selon les conditions de marché actuelles.
4.  **Surveillance** : L'EA journalise ses actions (signal détecté, ordre placé, filtre activé, etc.) dans l'onglet "Experts" du Terminal. Surveillez ces logs pour comprendre son fonctionnement.
5.  **Timeframe Conseillé** : L'EA est conçue pour fonctionner avec `ExecTF` sur M15 ou M30. Le graphique sur lequel il est attaché peut être H1 ou D1 pour une meilleure visualisation.

## Avertissement sur les Risques
**LE TRADING SUR MARCHÉS FINANCIERS IMPLIQUE DES RISQUES ÉLEVÉS DE PERTE.** Cet Expert Advisor est un outil d'automatisation et n'offre **aucune garantie de profit**. Les performances passées ne préjugent pas des résultats futurs.

*   **Test Rigoureux** : Testez l'EA exhaustivement en backtest et forward test (démo) avant toute utilisation en compte réel.
*   **Capital à Risquer** : N'engagez que du capital dont vous pouvez vous passer. Le paramètre `RiskPercent` doit être défini en conséquence (0.5% à 1% est une plage courante).
*   **Surveillance Active** : Aucun EA n'est infaillible. Une surveillance humaine régulière est indispensable, notamment lors d'événements macroéconomiques majeurs.
*   **Responsabilité** : Le développeur et le fournisseur de cet EA déclinent toute responsabilité concernant les pertes financières encourues par son utilisation. Vous êtes seul responsable de vos décisions de trading et de la configuration de l'EA.
*   **Prop Firms** : Bien que la gestion des risques soit conçue pour être stricte, vérifiez la compatibilité de la stratégie (notamment le nombre de trades, le drawdown) avec les règles spécifiques de votre fournisseur de fonds.

---
*Développé pour MetaTrader 5 - Stratégie Range Breakout Asian Session.*
```