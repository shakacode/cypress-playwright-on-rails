// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
//
// -- This is a parent command --
// Cypress.Commands.add("login", (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add("drag", { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add("dismiss", { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This is will overwrite an existing command --
// Cypress.Commands.overwrite("visit", (originalFn, url, options) => { ... })
//
//
// -- This is for Graphql usage. Add proxy-like mock to add operation name into query string --
// Cypress.Commands.add('mockGraphQL', () => {
//   cy.on('window:before:load', (win) => {
//     const originalFetch = win.fetch;
//     const fetch = (path, options, ...rest) => {
//       if (options && options.body) {
//         try {
//           const body = JSON.parse(options.body);
//           if (body.operationName) {
//             return originalFetch(`${path}?operation=${body.operationName}`, options, ...rest);
//           }
//         } catch (e) {
//           return originalFetch(path, options, ...rest);
//         }
//       }
//       return originalFetch(path, options, ...rest);
//     };
//     cy.stub(win, 'fetch', fetch);
//   });
// });
