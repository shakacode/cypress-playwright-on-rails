import type { SidebarsConfig } from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'introduction',
    'getting-started',
    {
      type: 'category',
      label: 'Test Runners',
      items: ['cypress', 'playwright'],
    },
    {
      type: 'category',
      label: 'Rails Test State',
      items: ['factory-bot', 'fixtures', 'scenarios', 'app-commands'],
    },
    {
      type: 'category',
      label: 'Guides',
      items: [
        'authentication',
        'factory_bot_associations',
        'BEST_PRACTICES',
        'TROUBLESHOOTING',
        'VCR_GUIDE',
        'DX_IMPROVEMENTS',
      ],
    },
    {
      type: 'category',
      label: 'Migration',
      items: ['migration/from-cypress-on-rails'],
    },
  ],
};

export default sidebars;
