#install.packages("simmer")
library(simmer)
library(simmer.plot)

opening_time <- 480 #Store Opening Hours
store_capacity <- 30 #Store Capacity
staff <- 3 #Staffing
checkout_counters <- 2 #Checkout Process


customer <- trajectory("customer's path") %>%
  #1. Customer Arrival 
  log_("Arrived at the store.") %>% ## State that the customer has arrived.
  renege_in(function() { rnorm(1, 3, 2)}, out = trajectory() %>% ## Set and start the timer.
              log_("Waited too long. Leaving...") %>% ## Define a trajectory if leaving.
              release_all() %>%
              set_attribute("Finished", 1) %>%
              leave(1)) %>%
  seize("First_Place_Queue") %>% ## Get the first place in the queue.
  renege_abort() %>% ## Stop the timer that was set.
  
  #2. Entering the Store
  seize("Store", amount = 1) %>% ## Get a place at the store (wait if there is no capacity).
  release("First_Place_Queue") %>% ## Release the first place in the queue.
  log_("The store has capacity. Entering now.") %>% ## State that there is capacity.
  
  #3. Browsing Inside the Store
  timeout(function() rnorm(1,5,2)) %>% ## Time to browse the store.
  branch( function() { runif(1) < 0.65 }, ## Set the probability of leaving 65%.
          continue = FALSE, trajectory() %>%  ## Define a trajectory when leaving.
            log_("Left the store after browsing.")%>%
            release("Store") %>%
            set_attribute("Finished", 2) %>%
            leave(1)) %>%
  
  #4. Asking for Assistance
  branch( function() { runif(1) < 0.7 }, 
          continue = TRUE, trajectory() %>%  ## Trajectory for asks for assistance.
            seize("Staff", continue = FALSE, reject = trajectory() %>%
                    log_("Cannot get help.") %>%
                    timeout(function() {rnorm(1, mean = 3, sd = 2)})%>%
                    rollback(target = 3, times = 2) %>%
                    set_attribute("Finished", 3) %>%
                    leave(1)) %>%
            leave(0.3, ## Setting the probability of leaving.
                  out = trajectory() %>% ## Defining an out trajectory whend doing so.
                    log_("Left the store after not being convinced by the staff.")%>%
                    set_attribute("Finished", 4) %>%
                    release_all()) %>%
            release("Staff")) %>%
  
  #5. Going to Pay
  log_("Going to pay.") %>% ## State that the customer is going to pay
  seize("Checkout", 1) %>% ## Get an automatic counter
  branch( function() { runif(1) < 0.05 }, ## Defining the branch to leaving before paying.
          continue = FALSE, trajectory() %>% 
            log_("Left the store without purchasing.") %>%
            set_attribute("Finished", 5)%>%
            release("Checkout", 1) %>%
            release("Store", 1) %>%
            leave(1)) %>%
  
  #6. Paying and Leaving
  timeout(rnorm(1, 5, 2)) %>% ## Waiting for checkout completion
  release("Checkout", 1) %>% ## Giving the spot in the checkout counter
  release("Store", 1) %>%  ## Giving the spot in the store
  set_attribute("Finished", 0) %>% ## Setting an attribute to know which customer has bought
  log_("Completed purchase, leaving the store.") ## Stating that the customer is leaving.


get_palette <- scales::brewer_pal(type = "qual", palette = 1) ## Define the color palette.
plot(customer, fill = get_palette) ## Get the desired plot.


set.seed(2021) ## Set a seed for replication purposes
envs <- lapply(1:1, function(i) { ## Applying how many times to simulate
  simmer("shop") %>%
    add_resource("Store", store_capacity) %>% ## Adding the store capacity.
    add_resource("First_Place_Queue", 1) %>% ## Adding the first place of the queue.
    add_resource("Staff", staff) %>% ## Adding the staff resource
    add_resource("Checkout", checkout_counters) %>% ## Adding the checkout counters 
    add_generator("Customer", customer, function() rexp(1, 1/3), mon=2) %>% ## Defining how often customers arrive.      
    run(until=opening_time) ## Runnning for the time that the store opens
}
)

# -------------------------- RESULTS -------------------------- 
get_mon_arrivals(envs)
data_finished_time <- data.frame(get_mon_arrivals(envs))
table(data_finished_time$finished)

dataset <- data.frame(get_mon_attributes(envs))

plot(get_mon_resources(envs), metric = "usage", items = "server",step = T)

write.csv(data_finished_time, "arrivals.csv", row.names = FALSE)
write.csv(dataset, "attributes.csv", row.names = FALSE)

#customer_in_a_day <- nrow(dataset)
#bought <- sum(dataset$value == 0)/customer_in_a_day
#left_1 <- sum(dataset$value == 1)/customer_in_a_day
#left_2 <- sum(dataset$value == 2)/customer_in_a_day
#left_3 <- sum(dataset$value == 3)/customer_in_a_day
#left_4 <- sum(dataset$value == 4)/customer_in_a_day
#left_5 <- sum(dataset$value == 5)/customer_in_a_day
