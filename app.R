#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
# install.packages(c("shinydashboard", "shiny", "babynames", "tidyverse", "ggplot2", "plotly"))
installed_packages = installed.packages()
needed_packages = c("shinydashboard", "shiny", "babynames", "tidyverse", "ggplot2", "plotly") 
needed_packages = needed_packages[!(needed_packages %in% installed_packages[,1])]
if(length(needed_packages > 0)) {
  install.packages(needed_packages)
}

is_in <- function(string, dataset) {
  
  filters = 
    lapply(string, function(x) str_detect(dataset$name, x))
  
  filter_mat = matrix(data = 0, nrow = nrow(dataset))

  filter_mat[,1] = filters[[1]]
  if(length(filters) >= 2) {
    for(i in 2:length(filters)) {
      filter_mat = cbind(filter_mat, filters[[i]])
    }
  }
  
  selected = rowSums(filter_mat) > 0
  
  selected
  
}

# debug(is_in)
library(shinydashboard)
library(shiny)
library(babynames)
library(tidyverse)
library(ggplot2) 
library(plotly)


babynames <- 
  babynames %>% 
  mutate(name = tolower(name))

ui <- dashboardPage(
  dashboardHeader(),
  dashboardSidebar(
    # h6('First time on load it\'s blank. Hit run to refresh!'),
    actionButton("do", "Hit me to run!"),
    # h6('Separate strings with commas: can be blank.'),
    textInput("name", "Find string:", ""),
    # h6('Separate strings with commas: can be blank.'),
    textInput("name_not", "Remove string:", ""),
    textInput("min_year", "Enter a minimum year:", "1900"),
    textInput("max_year", "Enter a maximum year:", "2010"),
    # h6('Selects N most popular names.'),
    # h6('Max 100 for top N, be patient for large values'),
    numericInput("top_n", "Select top N:", 20, min = 1, max = 100),
    # h6('Remove names which occur more than X times.'),
    numericInput("top_number", "Number <= :", 6000000, min = 1, max = Inf),
    # h6('Remove names which occur less than X times.'),
    numericInput("bottom_number", "Number >= :", 0, min = 1, max = Inf)
  ),
  dashboardBody(
    plotlyOutput("plot"),
    plotlyOutput("plot_prop"),
    dataTableOutput('table')
  )
)

server <- function(input, output) {
  
  clean_data = eventReactive(input$do, {
    
    max_year = as.numeric(input$max_year)
    min_year = as.numeric(input$min_year)
    
    baby_filtered <- 
      babynames %>% 
      filter(year >= min_year,
             year <= max_year)

    if(input$name != "") {
      char = 
        input$name %>% 
        str_split(",") %>% 
        unlist %>% 
        str_trim("both") %>% 
        tolower()
      
      baby_selected = is_in(char, baby_filtered)
      
      baby_filtered <- 
        baby_filtered %>% 
        filter(
          baby_selected
        )

    }
    
    if(input$name_not != "") {
      char_not = 
        input$name_not %>% 
        str_split(",") %>% 
        unlist %>% 
        str_trim("both") %>% 
        tolower()
      
      baby_removed  = !is_in(char_not, baby_filtered)
      
      baby_filtered <- 
        baby_filtered %>% 
        filter(
          baby_removed
        )
    }
    
    baby_filtered
    
  })
  
  data_input <- eventReactive(input$do, {

    baby_filtered <- clean_data()
    
    select_names <-
      baby_filtered %>%
      group_by(name) %>%
      summarise(n = sum(n)) %>%
      arrange(desc(n)) %>% 
      filter(n <= input$top_number,
             n >= input$bottom_number)
    
    top_n = input$top_n
    
    top_n = min(length(select_names$name), top_n)
    selected_names = select_names$name[1:top_n]
    
    baby_filtered <-
      baby_filtered %>%
      filter(name %in% selected_names)
    
    baby_filtered
  })
  
  output$plot <- renderPlotly(
    {
      data_from_output = data_input()
      
      gg_plot <- data_from_output %>% 
        ggplot() +
        aes(x = year, y = prop, col = name) +
        geom_path() 
      
      if(n_distinct(data_from_output$sex) == 2) {
        gg_plot =
          gg_plot +
          facet_grid(~ sex)
      }
      
      ggplotly(gg_plot)
      
    }
  )
  
  output$plot_prop <- renderPlotly(
    {
      data_from_output = data_input()
     
      gg_plot <- data_from_output %>% 
        ggplot() +
        aes(x = year, y = n, col = name) +
        geom_path() 
      
      if(n_distinct(data_from_output$sex) == 2) {
        gg_plot =
          gg_plot +
          facet_grid(~ sex)
      }
      
      ggplotly(gg_plot)
      
    }
  )
  
  output$table <- renderDataTable(
    {
      
      data_from_output = data_input()
      
      # data_from_output  %>% 
      #   arrange(n) %>% 
      #   head %>% 
      #   mutate(
      #     year = as.character(year),
      #     sex  = as.character(sex),
      #     name = as.character(name),
      #     n    = as.character(n),
      #     prop = round(prop, 4)
      #   ) %>% 
      #   as.data.frame()
      
      data_from_output %>% 
        group_by(name) %>%
        summarise(number = sum(n),
                  prop = mean(prop)) %>%
        arrange(desc(number))
      
    }
  )
  
}

shinyApp(ui, server)