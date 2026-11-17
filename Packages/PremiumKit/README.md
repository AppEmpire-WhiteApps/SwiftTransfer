# PremiumKit

Swift Package для интеграции in-app purchases через Apphud с удобным публичным API.

## Возможности

- Простая интеграция покупок через `Premium` сервис
- Автоматическая загрузка paywall с fallback на локальные данные
- Поддержка sandbox режима для тестирования
- Готовый `DemoContentView` для быстрого прототипирования
- Детальная обработка ошибок покупок (StoreKit 2)
- **OnboardingBuilder** — конструктор онбординг флоу с пейволом
- **PaywallBuilder** — конструктор пейвола для main флоу
- **Toggle/Picker для пар продуктов** — корректное переключение, когда из Apphud приходят два триальных или два безтриальных продукта
- **View-слоты** — кастомный background, middle layer и overlay для каждого экрана билдера
- **hideContent** — скрытие элементов контента (индикаторы, заголовок, подзаголовок, сообщение) per-screen
- **AdaptiveResources** — отдельные фоны для iPhone, iPhone SE, iPad и трёх состояний iPhone Duo (сложен, разложен вертикально и горизонтально)
- **Локализация** — встроенная поддержка 30 языков
- **Consumable продукты** — поддержка одноразовых покупок (токены)
- **Расширяемые ID** — кастомные `PremiumPaywallID` и `PaywallConfiguration`
- **WebBannerView** — WebView компонент для показа баннеров из Apphud

## Требования

- iOS 16.0+
- Swift 5.9+
- Xcode 15+

## Установка

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/AppEmpire-Utility/PremiumKit", from: "1.0.0")
]
```

## Быстрый старт

### 1. App Delegate

Подключите `PremiumAppDelegate` для автоматической инициализации:

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(PremiumAppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Если нужен свой делегат — наследуйтесь от `PremiumAppDelegate`:

```swift
class MyAppDelegate: PremiumAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        // своя логика
        return true
    }
}
```

### 2. Инициализация API Key

В точке входа приложения:

```swift
    init() {
        let apiKey = Bundle.main.infoDictionary?["PremiumAPIKey"] as? String ?? ""
        Premium.shared.configure(PremiumConfiguration(apiKey: apiKey))
    }
```

### Debug / Release режим

PremiumKit автоматически определяет режим сборки через `#if DEBUG`:

| | Debug | Release |
|---|---|---|
| **Данные пейвола** | Из Apphud (без fallback) | Fallback в sandbox, Apphud в production |
| **Покупки** | StoreKit 2 | Apphud |

Никаких флагов включать не нужно — всё работает автоматически.

### Логи

Логи PremiumKit включены по умолчанию и в Debug, и в Release. Они идут в консоль Xcode и в Console.app (subsystem `PremiumKit`, категории `paywall`, `fallback`, `purchase`, `localization`, `network`). Выключить:

```swift
Premium.shared.configure(PremiumConfiguration(apiKey: apiKey, isLoggingEnabled: false))
```

Пример:
```
ℹ️ [PremiumKit] Paywall main loaded — source: Apphud, configuration: variant2
ℹ️ [PremiumKit] Paywall shown — main
ℹ️ [PremiumKit] Purchase started — com.app.WeekTrial
⚠️ [PremiumKit] Paywall onboarding: Apphud load failed — product "com.app.Year" was not loaded from StoreKit → using fallback apphud_paywalls_fallback.json
❌ [PremiumKit] Fallback apphud_paywalls_fallback.json, paywall "main": json is invalid — invalid JSON — Unescaped control character around line 1, column 57. (a raw line break or tab inside a string: it must be escaped as \n or \t)
…"title": "Unlimited<LF>👉access", "products": […
```

Ошибки JSON показывают путь к полю (`products[1].periodly`) или место синтаксической ошибки с фрагментом текста: невидимые символы видны как `<LF>`, `<TAB>`, `<U+2028>`, `👉` — место ошибки. В Release фрагменты JSON помечены как private.

### 3. Загрузка Paywall

Загрузите onboarding и main paywall:

```swift
.task {
    await Premium.shared.loadPaywall(.onboarding)
}

.task {
    await Premium.shared.loadPaywall(.main)
}
```

### 4. Splash Screen и WebBanner

Добавьте оверлей для показа сплэш скрина, пока тянется пейвол:

```swift
    .overlay {
        if premiumService.isShowingSplash {
            DemoSplashView()
        }
    }
```

И вью модифайер для показа вебвью:

```swift
    .webBannerOverlay()
```        

### 5. Онбординг и Пейвол

Используйте билдеры для UI:

```swift
// Онбординг
OnboardingBuilder(
    screens: [...],
    paywallImages: AdaptiveResources(iphone: .paywall),
    onComplete: { }
)

// Пейвол
PaywallBuilder(
    images: AdaptiveResources(iphone: .paywall),
    onDismiss: { },
    onSuccess: { }
)
```

#### Адаптивные фоны

`AdaptiveResources` принимает отдельные картинки под устройство и его состояние. Обязателен только `iphone`, остальные опциональны:

```swift
AdaptiveResources(
    iphone: .paywall,
    iphoneS: .paywallSE,                // iPhone SE / 8 → фоллбэк iphone
    ipad: .paywallIpad,                 // iPad в портрете → фоллбэк iphone
    ipadL: .paywallIpadL,               // iPad в ландшафте → фоллбэк iphone
    duoFolded: .paywallDuoFolded,       // iPhone Duo сложен → фоллбэк iphone
    duoUnfolded: .paywallDuoUnfolded,   // iPhone Duo разложен вертикально → фоллбэк ipad
    duoUnfoldedL: .paywallDuoUnfoldedL  // iPhone Duo разложен горизонтально → фоллбэк ipadL
)
```

Вариант выбирается по размеру окна и size classes, фон переключается сразу при складывании и повороте. Подробнее — в статье Customization (DocC).

#### Отступы для unfolded landscape

Для `.duoUnfoldedLandscape` можно отдельно задать отступы основного контента:

```swift
OnboardingStyle(unfoldedLandscapePadding: .init(leading: 140, trailing: 56))
PaywallStyle(unfoldedLandscapePadding: .init(leading: 140, trailing: 56))
SecondaryPaywallStyle(
    layout: .init(unfoldedLandscapePadding: .init(leading: 140, trailing: 56))
)
```

Они заменяют `horizontalPadding` только в этом режиме. По умолчанию оба равны `16`, независимо от значения `horizontalPadding`. Тип экрана обновляется по размерам корневого контейнера и size classes во всех трёх билдерах, включая использование пользовательского фона.

#### View-слоты

Оба билдера поддерживают 3 опциональных view-слота:

| Слот | Описание |
|------|----------|
| `backgroundView` | Заменяет стандартный Image-фон |
| `middleView` | Между фоном и основным контентом |
| `overlayView` | Поверх всего (лоадеры, анимации) |

В **OnboardingBuilder** слоты задаются на каждый `OnboardingScreen`:

```swift
OnboardingScreen(
    id: 0,
    title1: "Welcome",
    subtitle: "Get started",
    images: AdaptiveResources(iphone: .onb1),
    backgroundView: { Color.black.ignoresSafeArea() },
    middleView: { FeatureAnimationView() },
    overlayView: { EmptyView() }
)
```

В **PaywallBuilder** слоты передаются в init:

```swift
PaywallBuilder(
    images: AdaptiveResources(iphone: .paywall),
    backgroundView: { GradientBackground() },
    middleView: { EmptyView() },
    overlayView: { CustomLoaderView() },
    onDismiss: { },
    onSuccess: { }
)
```

Все 3 слота опциональны — без них билдеры работают как раньше.

### 6. Проверка подписки и токены

```swift
@ObservedObject private var premium = Premium.shared

if premium.isPremium {
    // премиум контент
}

// Баланс токенов
let balance = premium.tokens

// Начисление токенов
premium.addTokens(10)

// Списание токенов
let success = premium.spendTokens()
```

### 7. Кастомные Paywall ID

`PremiumPaywallID` — расширяемый struct. Встроенные: `.onboarding`, `.main`, `.consumable`, `.banner`. Добавляйте свои:

```swift
extension PremiumPaywallID {
    static let yearSale = PremiumPaywallID("yearSale")
}

await Premium.shared.loadPaywall(.yearSale)
let paywall = Premium.shared.paywall(for: .yearSale)
```

## Документация

Подробная документация доступна в формате DocC: `Sources/PremiumKit/Documentation.docc/`

Для просмотра в Xcode: **Product → Build Documentation**

## Архитектура

```
PremiumKit/
├── Public/
│   ├── Premium/
│   │   ├── Premium.swift              # Публичный сервис
│   │   ├── PremiumConfiguration       # Конфигурация
│   │   ├── PremiumPaywallID           # Расширяемый ID пейвола
│   │   ├── PremiumPaywall             # Модель paywall
│   │   ├── PremiumProduct             # Модель продукта
│   │   ├── PremiumError               # Ошибки
│   │   └── PaywallConfiguration       # AB-конфигурация
│   │
│   └── Builders/
│       ├── Onboarding/
│       │   ├── OnboardingBuilder      # View онбординга
│       │   ├── OnboardingStyle        # Стили онбординга
│       │   └── OnboardingScreen       # Модель экрана
│       │
│       ├── Paywall/
│       │   ├── PaywallBuilder         # View пейвола
│       │   └── PaywallStyle           # Стили пейвола
│       │
│       └── Shared/
│           ├── AdaptiveResources      # Адаптивные изображения
│           ├── LinksConfiguration     # Конфигурация ссылок
│           └── LegalPresentationStyle # Стиль показа legal
│
├── Internal/
│   ├── Payment/
│   │   ├── PaymentManager             # Менеджер Apphud
│   │   ├── TokenStorage               # Хранение токенов (Keychain)
│   │   └── Fallback/                  # Fallback логика
│   └── Extensions/
│
├── Resources/
│   └── Localizable.xcstrings          # Локализация (30 языков)
│
├── Demo/                              # Демо компоненты
│
└── PremiumAppDelegate                 # App Delegate
```
