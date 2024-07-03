#!/bin/bash

list_of_users=$1
log_dir="/var/log"
log_file="/var/log/user_management.log"
password_dir="/var/secure"
password_manager="/var/secure/user_passwords.csv"

#Allow script run with sudo priviledges
if [[ "$(id -u)" -ne 0 ]]; then
    echo "The script must be run with root priviledges"
    echo "Running as root"
    sudo -E "$0" "$@"
    exit
fi


# Check if the input file is provided and it it contains any parameters
if [[ -z "$list_of_users" || ! -f "$list_of_users" ]]; then
    echo "Usage: $0 <list_of_user>"
    exit 1
fi



# Check the log directory exist
if [[ ! -d $log_dir ]]; then
    echo "The log directory does not exist. Creating log directory...."
    mkdir -p $log_dir
else
    echo "The log directory exist"
fi



# Check if the password directory exist
if [[ ! -d $password_dir ]]; then
    echo "The password directory does not exist. Creating password directory...."
    mkdir -p $password_dir
else
    echo "The password directory exist"
fi
    

# Ensure the log file exists and set the appropriate permissions
touch "$log_file"
chmod -R 755 "$log_file"


# Clear previous logs and initialize the password CSV file with a header
> "$log_file"
echo "username,password" > "$password_manager"
chmod 600 "$password_manager"  # Only the admin should have access to password files. 


# Generate random password function for users
#generate_password(){
    #tr -dc A-Za-z0-9 </dev/urandom | head -c 12
#}
generate_password(){
    # generates a 32-character random password
    urandom_data=$(head -c 32 /dev/urandom) 
    # Allows the 32-character random password to be encrypted allows `tr` to retrieve the alphanumeric characters and reduces the character to 12.
    # We don't start with generating a 12-character password because when it passes through `tr` it might not be up to 12. For security purposes the password
    # should be maximum of 12 characters.
    password=$(echo "$urandom_data" | openssl base64 | tr -dc A-Za-z0-9 | head -c 12)
    echo "$password"
}

# This function is used to create logs with time and date timestamps for verification purposes
logs_info(){
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

# Create users and groups function
create_users_groups(){
    echo "Create users and assign them to their departments"
    # define the parameters
    local users=$(echo "$1" | xargs) # Trim leading and trailing spaces
    local groups=$(echo "$2" | xargs) # Trim leading and trailing spaces 

    # Check for empty or invalid usernames or groups
    if [[ -z "$users" || -z "$groups" ]]; then
        logs_info "Skipping invalid line: $users, $groups" 
        return 1
    fi


    # check if user exist
    if id -u "$users" &>/dev/null; then
        logs_info "User $users already exists. Skipping." 
        return 1
    fi

     
    
    # Create personal group with the same name as the user
    if ! getent group "$users" &>/dev/null; then
        groupadd "$users"
        if [[ $? -eq 0 ]]; then
            logs_info "Created personal group $users for user $users." 
        else
            logs_info "Failed to create personal group $users." 
            return 1
        fi
    fi

    # Create groups if they don't exist
    IFS=',' read -ra group_list <<< "$groups"
    for group in "${group_list[@]}"; do
        group=$(echo "$group" | xargs) # Trim leading and trailing spaces
        if ! getent group "$group" &>/dev/null ; then
            groupadd "$group"
            if [[ $? -eq 0 ]]; then
                logs_info "Created group $group." 
            else
                logs_info "Failed to create group $group." 
                return 1
            fi
        fi
    done


    # Create the user with their name as primary groups
    useradd -m "$users" -g "$users" 
    if [ $? -ne 0 ]; then
        echo "Failed to create user $users."
        return 1
    fi
    echo "Created user $users with groups $groups."

    
  # Add the user to additional groups
    IFS=',' read -ra group_list <<< "$groups"
    for group in "${group_list[@]}"; do
        usermod -aG "$group" "$users"
        if [[ $? -eq 0 ]]; then
            logs_info "Assigned user $users to group $group."
        else
            logs_info "Failed to assign user $users to group $group." 
        fi
    done

    logs_info "Created user $users with groups $group." 


    # Set permissions and ownership for the home directory
    chmod 700 "/home/$users"
    chown "$users:$users" "/home/$users"
    logs_info "Set permissions for /home/$users." 



    # Generate a random password for the user
    local passwords
    passwords=$(generate_password)
    echo "$users:$passwords" | chpasswd
    if [ $? -ne 0 ]; then
        logs_info "Failed to set password for $user." 
        return 1
    fi
    logs_info "Generated password for $users." 



    # Store the password securely
    echo "$users,$passwords" >> "$password_manager"

    

    return 0

}



# Main logic
# Check if the file exist
if [[ -e "$list_of_users" ]]; then
    echo "The file $list_of_users exists."
else
    echo "The file $list_of_users does not exist."
fi


# Check if the file is not empty
if [[ -s "$list_of_users" ]]; then
    echo "The file $list_of_users is not empty"
else
    echo "The file $list_of_users is empty"
fi

# Calling the function

while IFS=';' read -r users groups; do
   echo "Read line: user='$users', groups='$groups'" # Debugging
   # Skip empty lines
    if [[ -z "$users" && -z "$groups" ]]; then
        continue
    fi
    create_users_groups "$users" "$groups"
done <  <(cat "$list_of_users"; echo)   # Ensure last line is processed                                            

logs_info "User creation process completed." 

exit 0
