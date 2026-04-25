## Pull Request

### Description
<!-- Concise summary of the change and motivation. Link to related issue if applicable. -->


### Type of Change
- [ ] 🐛 Bug fix (non-breaking change fixing an issue)
- [ ] ✨ New feature (non-breaking change adding functionality)
- [ ] 💥 Breaking change (fix or feature causing existing functionality to change)
- [ ] 📝 Documentation update
- [ ] 🎨 Style/UI change
- [ ] ♻️ Refactoring (no functional changes)
- [ ] 🧪 Test addition/update
- [ ] 🔧 Configuration change

### Stack Affected
- [ ] Backend (Laravel)
- [ ] Frontend (Next.js)
- [ ] Mobile (Flutter)
- [ ] Infrastructure / CI/CD
- [ ] Documentation

### Checklist

#### General
- [ ] My code follows the project's coding standards
- [ ] I have performed a self-review of my code
- [ ] My changes generate no new warnings or errors
- [ ] I have updated documentation accordingly

#### Backend (if applicable)
- [ ] `./vendor/bin/phpstan analyse` passes at Level 6
- [ ] `./vendor/bin/pint --test` passes
- [ ] `php artisan test` passes
- [ ] New endpoints documented in sprint task
- [ ] API responses follow `{ success, data, message }` format
- [ ] Form Request validation used for input
- [ ] No N+1 queries (checked with query detector)

#### Frontend (if applicable)
- [ ] `npm run lint` passes with zero `any` errors
- [ ] `npm run build` succeeds with zero warnings
- [ ] Prettier formatting applied
- [ ] All CSS uses logical properties (no `left`/`right`)
- [ ] Responsive design tested (mobile + desktop)
- [ ] Arabic RTL layout verified
- [ ] Dark mode tested

#### Mobile (if applicable)
- [ ] `flutter analyze` passes with zero issues
- [ ] `dart format` applied
- [ ] `flutter test` passes
- [ ] RTL layout verified
- [ ] Dark mode tested
- [ ] Tested on both iOS simulator and Android emulator

### Screenshots / Recordings
<!-- If UI change, include before/after screenshots or screen recordings -->


### Notes for Reviewers
<!-- Any specific areas to focus on, edge cases to test, etc. -->

