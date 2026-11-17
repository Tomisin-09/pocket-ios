import type { Metadata } from 'next'
import { RedMoonFooter, RedMoonNav } from '../_components/brand'
import RedMoonPrivacyBody from './RedMoonPrivacyBody'

// Red Moon's own policy: the app and redmoonpracticestudio.co.uk/privacy. Separate from Deco
// Operations' policy (app/privacy), which no longer covers Red Moon.
export const metadata: Metadata = {
  alternates: { canonical: '/privacy' },
  title: 'Privacy Policy — Red Moon Practice Studio',
  description:
    'What Red Moon Practice Studio does and does not do with your information. Your playing never reaches us.',
}

export default function RedMoonPrivacyPage() {
  return (
    <div className="rm-page">
      <RedMoonNav current="privacy" />

      <RedMoonPrivacyBody />

      <RedMoonFooter />
    </div>
  )
}
