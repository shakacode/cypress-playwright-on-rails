Rails.application.routes.draw do
  resources :posts
  get 'server_diagnostics/puma_stats' => 'server_diagnostics#puma_stats'
  root 'posts#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
