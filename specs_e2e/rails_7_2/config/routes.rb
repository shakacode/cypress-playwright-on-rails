Rails.application.routes.draw do
  resources :posts
  get 'server_diagnostics/puma_stats' => 'server_diagnostics#puma_stats'
  get 'server_diagnostics/reading_titles' => 'server_diagnostics#reading_titles'
  get 'server_diagnostics/hook_log' => 'server_diagnostics#hook_log'
  root 'posts#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
