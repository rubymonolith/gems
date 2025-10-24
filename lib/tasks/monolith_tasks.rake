namespace :monolith do
  namespace :tailwind do
    desc "Build Tailwind CSS for Monolith engine"
    task :build do
      system "bundle exec tailwindcss --input app/assets/stylesheets/monolith/application.tailwind.css --output app/assets/builds/monolith/tailwind.css --minify"
    end

    desc "Watch and rebuild Tailwind CSS for Monolith engine"
    task :watch do
      system "bundle exec tailwindcss --input app/assets/stylesheets/monolith/application.tailwind.css --output app/assets/builds/monolith/tailwind.css --watch"
    end
  end
end