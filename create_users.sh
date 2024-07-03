#!/bin/bash



list_of_users="/workspaces/users.txt"
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
chmod 600 "$password_manager"


# Generate random password function for users
generate_password(){
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}


# Create users and groups function
create_users_groups(){
    echo "Create users and assign them to their departments"
    # define the parameters
    local users=$(echo "$1" | xargs) # Trim leading and trailing spaces
    local groups=$(echo "$2" | xargs) # Trim leading and trailing spaces 

    # Check for empty or invalid usernames or groups
    if [[ -z "$users" || -z "$groups" ]]; then
        echo "Skipping invalid line: $users, $groups" | tee -a "$log_file"
        return 1
    fi


    # check if user exist
    if id -u "$users" &>/dev/null; then
        echo "User $users already exists. Skipping." | tee -a "$log_file"
        return 1
    fi

     
    # Create personal groups
    Create personal group with the same name as the user
    if ! getent group "$users" &>/dev/null; then
        groupadd "$users"
        if [[ $? -eq 0 ]]; then
            echo "Created personal group $users for user $users." | tee -a "$log_file"
        else
            echo "Failed to create personal group $users." | tee -a "$log_file"
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
                echo "Created group $group." | tee -a "$log_file"
            else
                echo "Failed to create group $group." | tee -a "$log_file"
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

    
  
    # Create the user with the specified groups
    if usermod -aG "$group" "$users"; then
        echo "Group "$group" assigned to user "$users""
    else
        echo "Group "$group" already assigned to user "$users""
    fi

    echo "Created user $users with groups $group." | tee -a "$log_file"


    # Set permissions and ownership for the home directory
    chmod 700 "/home/$users"
    chown "$users:$users" "/home/$users"
    echo "Set permissions for /home/$users." | tee -a "$log_file"



    # Generate a random password for the user
    local passwords
    passwords=$(generate_password)
    echo "$users:$passwords" | chpasswd
    echo "Generated password for $users." | tee -a "$log_file"



    # Store the password securely
    echo "$users:$passwords" >> "$password_manager"

    

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
done < "$list_of_users"

echo "User creation process completed." | tee -a "$log_file"

exit 0