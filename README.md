# Roblox Tycoon Game

משחק Tycoon מלא לרובלוקס עם 5 דרופרים, 4 שדרוגים, שמירת נתונים ו-UI.

---

## הוראות הגדרה ב-Roblox Studio

### שלב 1 - פתח Roblox Studio
1. פתח **Roblox Studio**
2. לחץ **New > Baseplate** (או כל template ריק)
3. שמור את הפרויקט בשם **"MyTycoon"**

---

### שלב 2 - הכנס את הסקריפטים

#### ReplicatedStorage
1. ב-Explorer, לחץ ימני על **ReplicatedStorage**
2. בחר **Insert Object > ModuleScript**
3. שנה שם ל- `GameConfig`
4. מחק את הקוד הקיים והדבק את תוכן `ReplicatedStorage/GameConfig.lua`

#### ServerScriptService - DataManager
1. לחץ ימני על **ServerScriptService**
2. בחר **Insert Object > Script**
3. שנה שם ל- `DataManager`
4. הדבק את תוכן `ServerScriptService/DataManager.server.lua`

#### ServerScriptService - PlotManager
1. לחץ ימני על **ServerScriptService**
2. בחר **Insert Object > Script**
3. שנה שם ל- `PlotManager`
4. הדבק את תוכן `ServerScriptService/PlotManager.server.lua`

#### ServerScriptService - MainGame
1. לחץ ימני על **ServerScriptService**
2. בחר **Insert Object > Script**
3. שנה שם ל- `MainGame`
4. הדבק את תוכן `ServerScriptService/MainGame.server.lua`

#### StarterGui - CashGui
1. לחץ ימני על **StarterGui**
2. בחר **Insert Object > LocalScript**
3. שנה שם ל- `CashGui`
4. הדבק את תוכן `StarterGui/CashGui.lua`

#### StarterPlayerScripts - TycoonClient
1. לחץ ימני על **StarterPlayerScripts**
2. בחר **Insert Object > LocalScript**
3. שנה שם ל- `TycoonClient`
4. הדבק את תוכן `StarterPlayerScripts/LocalScript.client.lua`

---

### שלב 3 - הפעל את המשחק

1. לחץ על כפתור **Play** (▶) ב-Roblox Studio
2. השחקן יתחיל על אחת מ-4 החלקות
3. הליכה על הכפתורים הכתומים = קניית Droppers
4. הליכה על הכפתורים הכחולים = קניית שדרוגים
5. הכדורים הירוקים עוברים לכיוון ה-Collector ומוסיפים כסף

---

## מבנה המשחק

```
ReplicatedStorage/
├── GameConfig (ModuleScript)    - הגדרות מחירים ומהירויות
└── Remotes/ (נוצר אוטומטית)
    ├── UpdateCash (RemoteEvent)
    ├── GetCash (RemoteFunction)
    ├── BuyDropper (RemoteEvent)
    ├── BuyUpgrade (RemoteEvent)
    └── Notify (RemoteEvent)

ServerScriptService/
├── DataManager (Script)         - שמירה/טעינה של כסף
├── PlotManager (Script)         - ניהול חלקות שחקנים
└── MainGame (Script)            - לוגיקה ראשית

StarterGui/
└── CashGui (LocalScript)        - הצגת כסף + התראות

StarterPlayerScripts/
└── TycoonClient (LocalScript)   - אפקטי קרבה לכפתורים
```

---

## הדרופרים

| שם | כסף לדרופ | מהירות | מחיר |
|---|---|---|---|
| Basic Dropper | $1 | 2 שניות | חינם |
| Silver Dropper | $5 | 2 שניות | $100 |
| Gold Dropper | $15 | 1.5 שניות | $500 |
| Diamond Dropper | $50 | 1 שנייה | $2,000 |
| Rainbow Dropper | $200 | 0.8 שניות | $10,000 |

## השדרוגים

| שם | אפקט | מחיר |
|---|---|---|
| Upgrade 1 | x2 הכנסה | $250 |
| Upgrade 2 | x3 הכנסה | $1,500 |
| Upgrade 3 | x5 הכנסה | $8,000 |
| Upgrade 4 | x10 הכנסה | $50,000 |

---

## שינוי הגדרות

כל ההגדרות נמצאות ב-`GameConfig` (ReplicatedStorage). שם ניתן לשנות:
- מחירי שדרוגים ודרופרים
- כמות כסף לדרופ
- מהירות הדרופרים
- מספר החלקות (NUM_PLOTS)
- שם מסד הנתונים (DATASTORE_NAME)
