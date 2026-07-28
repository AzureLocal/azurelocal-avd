import { defineConfig } from 'vitepress'

export default defineConfig({
  ignoreDeadLinks: true,
  base: '/azurelocal-avd/',
  title: "Azure Virtual Desktop on Azure Local",
  description: "Governed centrally by HCS Platform Engineering standards",
  themeConfig: {
    logo: '/assets/images/azurelocal-avd-icon.svg',
    nav: [{"link":"/","text":"Home"},{"items":[{"link":"/architecture/overview","text":"Overview"},{"link":"/architecture/deep-design","text":"Detailed Design"},{"link":"/architecture/fslogix-integration","text":"FSLogix Integration"},{"link":"/architecture","text":"Solution Architecture"}],"text":"Architecture"},{"link":"/getting-started","text":"Getting Started"},{"items":[{"link":"/guides/avd-deployment-guide","text":"AVD Deployment Guide"},{"link":"/guides/rdapps","text":"RemoteApps Guide"},{"link":"/guides/fslogix","text":"FSLogix Profile Containers"},{"link":"/guides/identity","text":"Identity & RBAC"},{"link":"/guides/scaling","text":"Scaling Plans"},{"link":"/guides/monitoring","text":"Monitoring & Diagnostics"},{"link":"/guides/networking","text":"Networking"},{"link":"/guides/validation-matrix","text":"Validation Matrix"}],"text":"Guides"},{"link":"/scenarios","text":"Scenarios"},{"items":[{"link":"/operations/cost-management","text":"Cost Management"},{"link":"/security/defender-operations","text":"Defender Operations"}],"text":"Operations"},{"items":[{"link":"/reference/variables","text":"Variables"},{"link":"/reference/variable-mapping","text":"Variable Mapping"},{"link":"/reference/tool-parity-matrix","text":"Tool Parity Matrix"},{"link":"/reference/phase-ownership","text":"Phase Ownership"},{"link":"/reference/monitoring-queries","text":"Monitoring Queries"},{"link":"/reference/host-pool-options","text":"Host Pool Options"},{"link":"/reference/rbac","text":"RBAC Reference"},{"link":"/reference/docs-validation-checklist","text":"Docs Validation Checklist"}],"text":"Reference"},{"link":"/roadmap","text":"Roadmap"},{"link":"/contributing","text":"Contributing"}],
    sidebar: [{"link":"/","text":"Home"},{"text":"Architecture","items":[{"link":"/architecture/overview","text":"Overview"},{"link":"/architecture/deep-design","text":"Detailed Design"},{"link":"/architecture/fslogix-integration","text":"FSLogix Integration"},{"link":"/architecture","text":"Solution Architecture"}],"collapsed":false},{"link":"/getting-started","text":"Getting Started"},{"text":"Guides","items":[{"link":"/guides/avd-deployment-guide","text":"AVD Deployment Guide"},{"link":"/guides/rdapps","text":"RemoteApps Guide"},{"link":"/guides/fslogix","text":"FSLogix Profile Containers"},{"link":"/guides/identity","text":"Identity & RBAC"},{"link":"/guides/scaling","text":"Scaling Plans"},{"link":"/guides/monitoring","text":"Monitoring & Diagnostics"},{"link":"/guides/networking","text":"Networking"},{"link":"/guides/validation-matrix","text":"Validation Matrix"}],"collapsed":false},{"link":"/scenarios","text":"Scenarios"},{"text":"Operations","items":[{"link":"/operations/cost-management","text":"Cost Management"},{"link":"/security/defender-operations","text":"Defender Operations"}],"collapsed":false},{"text":"Reference","items":[{"link":"/reference/variables","text":"Variables"},{"link":"/reference/variable-mapping","text":"Variable Mapping"},{"link":"/reference/tool-parity-matrix","text":"Tool Parity Matrix"},{"link":"/reference/phase-ownership","text":"Phase Ownership"},{"link":"/reference/monitoring-queries","text":"Monitoring Queries"},{"link":"/reference/host-pool-options","text":"Host Pool Options"},{"link":"/reference/rbac","text":"RBAC Reference"},{"link":"/reference/docs-validation-checklist","text":"Docs Validation Checklist"}],"collapsed":false},{"link":"/roadmap","text":"Roadmap"},{"link":"/contributing","text":"Contributing"}],
    socialLinks: [
      { icon: 'github', link: 'https://github.com/AzureLocal/azurelocal-avd' }
    ],
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © Hybrid Cloud Solutions & AzureLocal'
    }
  }
})




